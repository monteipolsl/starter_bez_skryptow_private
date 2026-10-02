`timescale 1ns / 1ps

// full_pipeline - see the task description for the requirements.
// Replace the placeholder assignments below with your implementation.

module full_pipeline #(
    parameter int W = 32
) (
    input logic clk,
    input logic rst,  // synchronous, active high

    // input side (from the upstream block)
    input  logic         s_valid,
    output logic         s_ready,
    input  logic [W-1:0] s_data,

    // output side (to the downstream block)
    output logic         m_valid,
    input  logic         m_ready,
    output logic [W-1:0] m_data
);

  //register for connecting to output port
  logic [W-1:0] data_reg;
  
  //connecting register to output port
  assign m_data  = data_reg;
  
  always_ff @(posedge clk) begin
    //synchronous reset
    if (rst) begin
      	s_ready <= 1'b1; //ready for new data
      	m_valid <= 1'b0; //no data in reg
    	  data_reg  <= '0; //resetting the reg
    end else begin
		//reading from buffer
	    if (m_valid && m_ready) begin          
          m_valid <= 1'b0;
          s_ready <= 1'b1;
      	end
	    //handshake, writing to buffer
		if (s_ready && s_valid) begin
			data_reg <= s_data;       
			m_valid <= 1'b1;
			s_ready <= 1'b0;      
     	end
    end
  end
  
endmodule
