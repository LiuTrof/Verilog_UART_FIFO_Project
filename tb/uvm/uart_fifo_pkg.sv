package uart_fifo_pkg;

    timeunit 1ns;
    timeprecision 1ps;

    import uvm_pkg::*;
    `include "uvm_macros.svh"

    localparam time BIT_PERIOD_NS      = 104_160ns;
    localparam time HALF_BIT_PERIOD_NS = BIT_PERIOD_NS / 2;
    localparam time FRAME_GAP_NS       = BIT_PERIOD_NS * 6;

    `uvm_analysis_imp_decl(_expected)
    `uvm_analysis_imp_decl(_actual)

    // One UART payload transaction. Framing is a driver responsibility.
    class uart_item extends uvm_sequence_item;
        rand bit [7:0] data;

        `uvm_object_utils_begin(uart_item)
            `uvm_field_int(data, UVM_DEFAULT)
        `uvm_object_utils_end

        function new(string name = "uart_item");
            super.new(name);
        endfunction
    endclass

    class uart_sequence extends uvm_sequence #(uart_item);
        bit [7:0] payloads[$];
        time inter_byte_gap;

        `uvm_object_utils(uart_sequence)

        function new(string name = "uart_sequence");
            super.new(name);
            inter_byte_gap = 0ns;
        endfunction

        task body();
            uart_item item;
            foreach (payloads[index]) begin
                item = uart_item::type_id::create($sformatf("item_%0d", index));
                start_item(item);
                item.data = payloads[index];
                finish_item(item);
                if (inter_byte_gap != 0ns && index != payloads.size() - 1) begin
                    #(inter_byte_gap);
                end
            end
        endtask
    endclass

    class uart_driver extends uvm_driver #(uart_item);
        virtual uart_fifo_if vif;
        uvm_analysis_port #(uart_item) expected_ap;

        `uvm_component_utils(uart_driver)

        function new(string name, uvm_component parent);
            super.new(name, parent);
            expected_ap = new("expected_ap", this);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            if (!uvm_config_db#(virtual uart_fifo_if)::get(this, "", "vif", vif)) begin
                `uvm_fatal("NOVIF", "uart_driver requires virtual interface vif")
            end
        endfunction

        task run_phase(uvm_phase phase);
            uart_item expected;
            forever begin
                seq_item_port.get_next_item(req);
                expected = uart_item::type_id::create("expected");
                expected.copy(req);
                expected_ap.write(expected);
                drive_byte(req.data);
                seq_item_port.item_done();
            end
        endtask

        task apply_reset();
            vif.rx <= 1'b1;
            vif.reset <= 1'b1;
            repeat (20) @(posedge vif.clk);
            vif.reset <= 1'b0;
            repeat (20) @(posedge vif.clk);
            `uvm_info("DRV", $sformatf("reset released at %0t", $time), UVM_MEDIUM)
        endtask

        protected task drive_byte(bit [7:0] data);
            vif.driver_data <= data;
            `uvm_info("DRV", $sformatf("send 0x%02h at %0t", data, $time), UVM_MEDIUM)

            vif.rx <= 1'b1;
            #(BIT_PERIOD_NS);
            vif.rx <= 1'b0;
            #(BIT_PERIOD_NS);
            for (int bit_index = 0; bit_index < 8; bit_index++) begin
                vif.rx <= data[bit_index];
                #(BIT_PERIOD_NS);
            end
            vif.rx <= 1'b1;
            #(BIT_PERIOD_NS);
            #(FRAME_GAP_NS);
        endtask
    endclass

    class uart_monitor extends uvm_component;
        virtual uart_fifo_if vif;
        uvm_analysis_port #(uart_item) actual_ap;

        `uvm_component_utils(uart_monitor)

        function new(string name, uvm_component parent);
            super.new(name, parent);
            actual_ap = new("actual_ap", this);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            if (!uvm_config_db#(virtual uart_fifo_if)::get(this, "", "vif", vif)) begin
                `uvm_fatal("NOVIF", "uart_monitor requires virtual interface vif")
            end
        endfunction

        task run_phase(uvm_phase phase);
            uart_item observed;
            bit [7:0] data;
            forever begin
                @(negedge vif.tx);
                if (vif.reset) begin
                    continue;
                end

                #(BIT_PERIOD_NS + HALF_BIT_PERIOD_NS);
                for (int bit_index = 0; bit_index < 8; bit_index++) begin
                    data[bit_index] = vif.tx;
                    #(BIT_PERIOD_NS);
                end
                #(BIT_PERIOD_NS);

                vif.monitor_data <= data;
                observed = uart_item::type_id::create("observed");
                observed.data = data;
                actual_ap.write(observed);
                `uvm_info("MON", $sformatf("received 0x%02h at %0t", data, $time), UVM_MEDIUM)
            end
        endtask
    endclass

    class uart_agent extends uvm_agent;
        uvm_sequencer #(uart_item) sequencer;
        uart_driver driver;
        uart_monitor monitor;

        `uvm_component_utils(uart_agent)

        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            sequencer = uvm_sequencer#(uart_item)::type_id::create("sequencer", this);
            driver    = uart_driver::type_id::create("driver", this);
            monitor   = uart_monitor::type_id::create("monitor", this);
        endfunction

        function void connect_phase(uvm_phase phase);
            super.connect_phase(phase);
            driver.seq_item_port.connect(sequencer.seq_item_export);
        endfunction
    endclass

    class uart_fifo_scoreboard extends uvm_component;
        uvm_analysis_imp_expected #(uart_item, uart_fifo_scoreboard) expected_export;
        uvm_analysis_imp_actual #(uart_item, uart_fifo_scoreboard) actual_export;
        uart_item expected_queue[$];
        int unsigned checked_count;
        int unsigned error_count;

        `uvm_component_utils(uart_fifo_scoreboard)

        function new(string name, uvm_component parent);
            super.new(name, parent);
            expected_export = new("expected_export", this);
            actual_export   = new("actual_export", this);
        endfunction

        function void write_expected(uart_item expected);
            uart_item expected_copy;
            expected_copy = uart_item::type_id::create("expected_copy");
            expected_copy.copy(expected);
            expected_queue.push_back(expected_copy);
            `uvm_info("SCB", $sformatf("expect 0x%02h (pending=%0d)",
                      expected.data, expected_queue.size()), UVM_HIGH)
        endfunction

        function void write_actual(uart_item actual);
            uart_item expected;
            checked_count++;
            if (expected_queue.size() == 0) begin
                error_count++;
                `uvm_error("SCB", $sformatf("unexpected output 0x%02h at %0t", actual.data, $time))
                return;
            end

            expected = expected_queue.pop_front();
            if (actual.data !== expected.data) begin
                error_count++;
                `uvm_error("SCB", $sformatf("mismatch: expected 0x%02h, got 0x%02h at %0t",
                          expected.data, actual.data, $time))
            end else begin
                `uvm_info("SCB", $sformatf("match 0x%02h (checked=%0d)",
                          actual.data, checked_count), UVM_MEDIUM)
            end
        endfunction

        task wait_for_all_expected(time timeout);
            time deadline = $time + timeout;
            while (expected_queue.size() != 0 && $time < deadline) begin
                #BIT_PERIOD_NS;
            end
            if (expected_queue.size() != 0) begin
                error_count++;
                `uvm_error("SCB", $sformatf("timeout with %0d unmatched expected byte(s)",
                          expected_queue.size()))
            end
        endtask

        function void check_phase(uvm_phase phase);
            super.check_phase(phase);
            if (expected_queue.size() != 0) begin
                error_count++;
                `uvm_error("SCB", $sformatf("test ended with %0d unmatched expected byte(s)",
                          expected_queue.size()))
            end
        endfunction

        function void report_phase(uvm_phase phase);
            `uvm_info("SCB", $sformatf("checked=%0d errors=%0d pending=%0d",
                      checked_count, error_count, expected_queue.size()), UVM_NONE)
        endfunction
    endclass

    class uart_fifo_checker extends uvm_component;
        virtual uart_fifo_status_if status_vif;
        int unsigned error_count;

        `uvm_component_utils(uart_fifo_checker)

        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            if (!uvm_config_db#(virtual uart_fifo_status_if)::get(this, "", "status_vif", status_vif)) begin
                `uvm_fatal("NOVIF", "uart_fifo_checker requires status_vif")
            end
        endfunction

        task run_phase(uvm_phase phase);
            forever begin
                @(posedge status_vif.clk);
                if (!status_vif.reset) begin
                    if (status_vif.rx_full && status_vif.rx_empty) begin
                        error_count++;
                        `uvm_error("FIFO", "RX FIFO full and empty are both asserted")
                    end
                    if (status_vif.tx_full && status_vif.tx_empty) begin
                        error_count++;
                        `uvm_error("FIFO", "TX FIFO full and empty are both asserted")
                    end
                    if (status_vif.boundary_full && status_vif.boundary_empty) begin
                        error_count++;
                        `uvm_error("FIFO", "boundary FIFO full and empty are both asserted")
                    end
                end
            end
        endtask
    endclass

    class uart_fifo_env extends uvm_env;
        uart_agent agent;
        uart_fifo_scoreboard scoreboard;
        uart_fifo_checker checker;

        `uvm_component_utils(uart_fifo_env)

        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            agent      = uart_agent::type_id::create("agent", this);
            scoreboard = uart_fifo_scoreboard::type_id::create("scoreboard", this);
            checker    = uart_fifo_checker::type_id::create("checker", this);
        endfunction

        function void connect_phase(uvm_phase phase);
            super.connect_phase(phase);
            agent.driver.expected_ap.connect(scoreboard.expected_export);
            agent.monitor.actual_ap.connect(scoreboard.actual_export);
        endfunction
    endclass

    class uart_fifo_test extends uvm_test;
        uart_fifo_env env;
        virtual fifo_boundary_if fifo_vif;
        string selected_test;

        `uvm_component_utils(uart_fifo_test)

        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            env = uart_fifo_env::type_id::create("env", this);
            if (!uvm_config_db#(virtual fifo_boundary_if)::get(this, "", "fifo_vif", fifo_vif)) begin
                `uvm_fatal("NOVIF", "uart_fifo_test requires fifo_vif")
            end
        endfunction

        task run_phase(uvm_phase phase);
            phase.raise_objection(this);
            if (!$value$plusargs("TEST=%s", selected_test)) begin
                selected_test = "all";
            end
            `uvm_info("TEST", $sformatf("selected test=%s", selected_test), UVM_NONE)

            case (selected_test)
                "single": run_single();
                "multi":  run_multi();
                "stream": run_stream();
                "fifo":   run_fifo_boundary();
                "reset":  run_reset_recovery();
                "all":    run_all();
                default: begin
                    `uvm_fatal("TEST", $sformatf("unsupported +TEST=%s", selected_test))
                end
            endcase

            if (env.scoreboard.error_count != 0 || env.checker.error_count != 0) begin
                `uvm_fatal("RESULT", $sformatf("TEST FAIL: scoreboard=%0d checker=%0d",
                           env.scoreboard.error_count, env.checker.error_count))
            end
            `uvm_info("RESULT", "TEST PASS", UVM_NONE)
            phase.drop_objection(this);
        endtask

        protected task send_bytes(bit [7:0] payloads[$], time inter_byte_gap = 0ns);
            uart_sequence sequence;
            sequence = uart_sequence::type_id::create("sequence");
            sequence.payloads = payloads;
            sequence.inter_byte_gap = inter_byte_gap;
            sequence.start(env.agent.sequencer);
            env.scoreboard.wait_for_all_expected(40 * BIT_PERIOD_NS);
        endtask

        protected task run_single();
            bit [7:0] payloads[$] = '{8'hA5};
            env.agent.driver.apply_reset();
            send_bytes(payloads);
        endtask

        protected task run_multi();
            bit [7:0] payloads[$] = '{8'h11, 8'h22, 8'h33, 8'h44};
            env.agent.driver.apply_reset();
            send_bytes(payloads, 12 * BIT_PERIOD_NS);
        endtask

        protected task run_stream();
            bit [7:0] payloads[$];
            for (int index = 0; index < 20; index++) begin
                payloads.push_back(index[7:0]);
            end
            env.agent.driver.apply_reset();
            send_bytes(payloads, 12 * BIT_PERIOD_NS);
        endtask

        protected task run_fifo_boundary();
            fifo_vif.reset <= 1'b1;
            fifo_vif.wr_en <= 1'b0;
            fifo_vif.rd_en <= 1'b0;
            fifo_vif.wdata <= '0;
            repeat (3) @(posedge fifo_vif.clk);
            fifo_vif.reset <= 1'b0;
            repeat (2) @(posedge fifo_vif.clk);

            for (int index = 0; index < 8; index++) begin
                fifo_vif.wdata <= index[7:0];
                fifo_vif.wr_en <= 1'b1;
                @(posedge fifo_vif.clk);
            end
            fifo_vif.wr_en <= 1'b0;
            @(posedge fifo_vif.clk);
            if (fifo_vif.full !== 1'b1) begin
                env.checker.error_count++;
                `uvm_error("FIFO", "full was not asserted after eight writes")
            end

            for (int index = 0; index < 8; index++) begin
                fifo_vif.rd_en <= 1'b1;
                @(posedge fifo_vif.clk);
            end
            fifo_vif.rd_en <= 1'b0;
            @(posedge fifo_vif.clk);
            if (fifo_vif.empty !== 1'b1) begin
                env.checker.error_count++;
                `uvm_error("FIFO", "empty was not asserted after eight reads")
            end
        endtask

        protected task run_reset_recovery();
            bit [7:0] payloads[$] = '{8'hA5};
            env.agent.driver.apply_reset();
            send_bytes(payloads, 12 * BIT_PERIOD_NS);
        endtask

        protected task run_all();
            run_single();
            run_multi();
            run_stream();
            run_fifo_boundary();
            run_reset_recovery();
        endtask
    endclass

endpackage
