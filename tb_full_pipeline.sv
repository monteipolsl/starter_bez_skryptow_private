// Testbench for full_pipeline.
//
// Everything except the send() task and the scoreboard is provided - see the
// TODOs below.
//
// All data words from the source file are sent through the DUT twice:
//   1. full performance - s_valid and m_ready held high
//   2. randomized       - source: on each cycle outside a gap, before offering a
//                         word, a gap of 1..MAX_GAP idle cycles (uniform) starts
//                         with probability GAP_PROB; gaps never start while a word
//                         waits for s_ready. Sink: m_ready high with READY_PROB.
//
// The scoreboard checks the data (order and values); the word counts are
// checked at the end of the test.
// Every cycle after reset one row "s_valid s_ready s_data m_valid m_ready m_data"
// is written to the sink file; "# phase N" lines mark where each phase starts.
// Throughput and handshake protocol checks are done on that file by
// scripts/analyze.py.
//
// Plusargs (all optional):
//   +SOURCE=<file>   data words, one hex word per line (default: build/source.txt)
//   +SINK=<file>     cycle trace                       (default: build/sink.txt)
//   +SEED=<n>        random seed                       (default: 1)
//   +GAP_PROB=<p>    phase 2 gap probability           (default: 0.3)
//   +MAX_GAP=<n>     phase 2 maximum gap length        (default: 4)
//   +READY_PROB=<p>  phase 2 m_ready probability       (default: 0.5)
//   +TIMEOUT=<n>     maximum number of clock cycles    (default: 4x expected)
//   +VCD             write build/tb_full_pipeline.vcd
//
// The data width is set at compile time with -DW=<n> (default 32).

`timescale 1ns / 1ps

`ifndef W
`define W 32
`endif

module tb_full_pipeline;

    localparam int W = `W;
    localparam int RESET_CYCLES = 4;
    localparam int DRAIN_CYCLES = 4;  // idle cycles after each phase

    // DUT signals; s_data is 'x whenever s_valid is low
    logic         clk     = 1'b0;
    logic         rst     = 1'b1;

    logic         s_valid = 1'b0;
    logic         s_ready;
    logic [W-1:0] s_data  = 'x;

    logic         m_valid;
    logic         m_ready = 1'b0;
    logic [W-1:0] m_data;

    // configuration (plusargs)
    string        source_file = "build/source.txt";
    string        sink_file   = "build/sink.txt";
    int           seed        = 1;
    real          gap_prob    = 0.3;
    int           max_gap     = 4;
    real          ready_prob  = 0.5;
    int           timeout     = -1;

    // state
    logic [W-1:0] words[$];     // data words from the source file
    int           cycle        = 0;
    int           phase        = 0;
    int           logged_phase = 0;
    int           sink_fd      = 0;
    int           n_in         = 0;
    int           n_out        = 0;
    int           errors       = 0;  // incremented by the scoreboard

    // ---------------------------------------------------------------- DUT

    full_pipeline #(
        .W       (W)
    ) dut (
        .clk     (clk),
        .rst     (rst),
        .s_valid (s_valid),
        .s_ready (s_ready),
        .s_data  (s_data),
        .m_valid (m_valid),
        .m_ready (m_ready),
        .m_data  (m_data)
    );

    always #5 clk = ~clk;

    always @(posedge clk) if (!rst) cycle <= cycle + 1;

    // ---------------------------------------------------------------- helpers

    // true with probability p (resolution 1e-6)
    function automatic bit chance(real p);
        return ($unsigned($random(seed)) % 1000000) < p * 1.0e6;
    endfunction

    // uniform in 1..max
    function automatic int rand_gap(int max);
        return 1 + $unsigned($random(seed)) % max;
    endfunction

    task automatic read_source();
        int           fd;
        logic [W-1:0] d;
        fd = $fopen(source_file, "r");
        if (fd == 0) begin
            $display("ERROR: cannot open %s - run make stim first", source_file);
            $fatal(1);
        end
        while ($fscanf(fd, "%h\n", d) == 1) words.push_back(d);
        $fclose(fd);
        if (words.size() == 0) begin
            $display("ERROR: no data words in %s", source_file);
            $fatal(1);
        end
    endtask

    task automatic open_sink();
        sink_fd = $fopen(sink_file, "w");
        if (sink_fd == 0) begin
            $display("ERROR: cannot write %s", sink_file);
            $fatal(1);
        end
        $fdisplay(sink_fd, "# W=%0d SEED=%0d GAP_PROB=%0.3f MAX_GAP=%0d READY_PROB=%0.3f",
                  W, seed, gap_prob, max_gap, ready_prob);
        $fdisplay(sink_fd, "# s_valid s_ready s_data m_valid m_ready m_data");
    endtask

    // Transfer one word d into the DUT on the input side.
    //
    // TODO: implement this task.
    //   The task is always called just after a rising edge of clk. It must:
    //   - offer d to the DUT as a valid word,
    //   - keep offering it, with the data unchanged, until the DUT accepts it
    //     according to the valid/ready handshake rules,
    //   - return just after the rising edge on which the word was transferred,
    //     leaving the input side idle (s_valid low, s_data 'x).
    //   Calls that follow each other with no delay must transfer the words back
    //   to back: when the DUT is always ready (phase 1), one word is transferred
    //   in every clock cycle, without an idle cycle between the words.
    //   Drive the signals the way a register clocked by clk would, so that the
    //   DUT and the rest of the testbench see stable values at each rising edge.
    task automatic send(input logic [W-1:0] d);
	  //from upstream block (tb)
      
	  s_data  <= d;
      s_valid <= 1'b1;
      
	  //$display("[1] before writting to buffer (should be 1) @(posedge clk) s_ready = ", s_ready);
	  @(posedge clk);//po tym clk przepisujemy s_data -> reg
	  //$display("[2] after buffer is full (should be 0) @(posedge clk) s_ready = ", s_ready);
	  while (!s_ready) begin
		@(posedge clk);
	  end
	        
	  //may cause
	  //$display("[3] after while loop (should be 1) s_ready = ", s_ready);
      s_valid <= 1'b0;
      s_data  <= 'x; 
   
    endtask

    // wait until n words have left the DUT, then a few idle cycles to catch
    // spurious outputs
    task automatic drain(input int n);
        while (n_out < n) @(posedge clk);
        repeat (DRAIN_CYCLES) @(posedge clk);
    endtask

    // ------------------------------------------------------ trace, counters

    always @(posedge clk) if (!rst) begin
        if (phase != logged_phase) begin
            $fdisplay(sink_fd, "# phase %0d", phase);
            logged_phase = phase;
        end
        $fdisplay(sink_fd, "%b %b %h %b %b %h", s_valid, s_ready, s_data, m_valid, m_ready, m_data);
        if (s_valid && s_ready) n_in++;
        if (m_valid && m_ready) n_out++;
    end

    // ------------------------------------------------------------ scoreboard

    // TODO: implement the scoreboard.
    //   Consider only words actually transferred according to the valid/ready
    //   handshake rules - not the value on the data bus in every cycle.
    //   Check that the words transferred out of the DUT are exactly the words
    //   transferred into it, in the same order. For every wrong or unexpected
    //   output word, $display a line starting with "ERROR" and increment errors.
	logic [W-1:0] expected[$];
	
	always @(posedge clk) begin
	
		//upstream handshake
		if (s_ready && s_valid) begin
			expected.push_back(s_data);
		end	
		
		//downstream handshake
		if (m_ready && m_valid) begin
		
			if (expected.size() == 0) begin
				$display("ERROR: unexpected m_data word: %h", m_data);
				errors++;
			end
			else if (m_data !== expected[0]) begin //!== because of X and Z
				$display("ERROR: data mismatch: m_data = %h || expected = %h", m_data, expected[0]);
				expected.pop_front(); //remove one mismatch so following words will be ok
				errors++;
			end
			else begin //m_data === expected[0]
				$display("PASS: m_data = %h == expected[0] == %h", m_data, expected[0]);
				expected.pop_front();
			end
		end
		
		if (errors != 0) begin
			//$display("Errors in scoreboard: %h", errors);
		end
		
	end
    // ----------------------------------------------------------------- test

    initial begin
        int n;

        if ($value$plusargs("SOURCE=%s", source_file)) ;
        if ($value$plusargs("SINK=%s", sink_file)) ;
        if ($value$plusargs("SEED=%d", seed)) ;
        if ($value$plusargs("GAP_PROB=%f", gap_prob)) ;
        if ($value$plusargs("MAX_GAP=%d", max_gap)) ;
        if ($value$plusargs("READY_PROB=%f", ready_prob)) ;
        if ($value$plusargs("TIMEOUT=%d", timeout)) ;

        if (gap_prob < 0.0 || gap_prob >= 1.0 || max_gap < 1 || ready_prob <= 0.0 || ready_prob > 1.0) begin
            $display("ERROR: need 0.0 <= GAP_PROB < 1.0, MAX_GAP >= 1, 0.0 < READY_PROB <= 1.0");
            $fatal(1);
        end

        read_source();
        n = words.size();
        // 4x the expected cycle count of both phases
        if (timeout < 0)
            timeout = $rtoi(4.0 * n * (2.0 + gap_prob / (1.0 - gap_prob) * (max_gap + 1) / 2.0
                                       + 1.0 / ready_prob)) + 1000;
        open_sink();

        $display("W=%0d words=%0d SEED=%0d GAP_PROB=%0.3f MAX_GAP=%0d READY_PROB=%0.3f TIMEOUT=%0d",
                 W, n, seed, gap_prob, max_gap, ready_prob, timeout);

        if ($test$plusargs("VCD")) begin
            $dumpfile("build/tb_full_pipeline.vcd");
            $dumpvars(0, tb_full_pipeline);
        end

        repeat (RESET_CYCLES) @(posedge clk);
        rst <= 1'b0;

        // phase 1: full performance
        // (phase is updated with <= so the trace marker lands deterministically
        // before the first row of the new phase)
        phase   <= 1;
        m_ready <= 1'b1;
        foreach (words[i]) send(words[i]);
        drain(n);

        // phase 2: randomized valid/ready
        phase <= 2;
        fork
            foreach (words[i]) begin
                while (chance(gap_prob)) repeat (rand_gap(max_gap)) @(posedge clk);
                send(words[i]);
            end
            begin
                while (n_out < 2 * n) begin
                    m_ready <= chance(ready_prob);
                    @(posedge clk);
                end
                m_ready <= 1'b1;
            end
        join
        drain(2 * n);

        $fclose(sink_fd);
        if (n_in != 2 * n || n_out != 2 * n) begin
            $display("ERROR: expected %0d words in and out, got in=%0d out=%0d", 2 * n, n_in, n_out);
            errors++;
        end
        $display("RESULT in=%0d out=%0d cycles=%0d errors=%0d trace=%s",
                 n_in, n_out, cycle, errors, sink_file);
        if (errors != 0) $fatal(1);
        $display("PASS");
        $finish;
    end

    initial begin
        wait (!rst && cycle >= timeout);
        $display("ERROR: timeout after %0d cycles", timeout);
        $fatal(1);
    end

endmodule
