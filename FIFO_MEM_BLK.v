`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 23.10.2026 04:09:23
// Design Name: 
// Module Name: FIFO_MEM_BLK
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

`define  FWIDTH     32           // Width of the FIFO. 
`define  FDEPTH     4            // Depth of the FIFO. 
`define  FCWIDTH    2 

module FIFO_MEM_BLK( clk, 
                     writeN, 
                     wr_addr, 
                     rd_addr, 
                     data_in, 
                     data_out 
                   ); 
 
 
input                    clk;       // input clk. 
input  writeN;  // Write Signal to put data into fifo. 
input  [(`FCWIDTH-1):0]  wr_addr;   // Write Address. 
input  [(`FCWIDTH-1):0]  rd_addr;   // Read Address. 
input  [(`FWIDTH-1):0]   data_in;   // DataIn in to Memory Block 
 
output [(`FWIDTH-1):0]   data_out;  // Data Out from the Memory 
                                    // Block(FIFO) 
 
wire   [(`FWIDTH-1):0] data_out; 
 
reg    [(`FWIDTH-1):0] FIFO[0:(`FDEPTH-1)]; 
 
 
 
assign data_out  = FIFO[rd_addr]; 
 
always @(posedge clk) 
begin 
 
   if(writeN==1'b0) 
      FIFO[wr_addr] <= data_in; 
end 
 
endmodule 
