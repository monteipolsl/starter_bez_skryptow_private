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

  //registers for connecting to output ports
  logic			ready_reg
  logic 		valid_reg;
  logic [W-1:0] data_reg;
  
  //connecting registers to output ports
  assign s_ready = ready_reg;
  assign m_valid = valid_reg;
  assign m_data  = data_reg;
  
  always_ff @(posedge clk) begin
    //synchronous reset
    if (rst) begin
      	ready_reg <= 1'b0;
      	valid_reg <= 1'b0;
    	data_reg  <= '0;
    end else begin
      if (s_ready && m_valid) begin
        s_data <= data_reg;        
      end else begin
        s_data <= '0;
      end
    end
  end
  
  
endmodule
