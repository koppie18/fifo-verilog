`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////// 
// FileName:  "Fifo.v" 
// Author  :  Venkata Ramana Kalapatapu 
// Company :  Sand Microelectronics Inc. 
//           (now a part of Synopsys, Inc.), 
// Profile :  Sand develops Simulation Models, Synthesizable Cores and 
//           Performance Analysis Tools for Processors, buses and 
//           memory products.  Sand's products include models for 
//           industry-standard components and custom-developed models 
//           for specific simulation environments. 
// 
////////////////////////////////////////////////////////////////////

 
`define  FWIDTH     32           // Width of the FIFO. 
`define  FDEPTH     4            // Depth of the FIFO. 
`define  FCWIDTH    2            // Counter Width of the FIFO 2 to 

                                 // FCWIDTH = FDEPTH. 
module fifo_ptr( Clk, 
              RstN, 
              Data_In, 
              FClrN, 
              FInN, 
              FOutN, 
 
              F_Data, 
              F_FullN, 
              F_LastN, 
              F_SLastN, 
              F_FirstN, 
              F_EmptyN 
           ); 
 
 
 
input                       Clk;      // CLK signal. 
input                       RstN;     // Low Asserted Reset signal. 
input [(`FWIDTH-1):0]       Data_In;  // Data into FIFO. 
input                       FInN;     // Write into FIFO Signal. 
input                       FClrN;    // Clear signal to FIFO. 
input                       FOutN;    // Read from FIFO signal. 
 
output [(`FWIDTH-1):0]      F_Data;   // FIFO data out. 
output                      F_FullN;  // FIFO full indicating signal. 
output                      F_EmptyN; // FIFO empty indicating signal. 
output                      F_LastN;  // FIFO Last but one signal. 
output                      F_SLastN; // FIFO SLast but one signal. 
output                      F_FirstN; // Signal indicating only one 
                                      // word in FIFO. 
 
 
 
 
 
 
 

reg                F_FullN; 
reg                F_EmptyN; 
reg                F_LastN; 
reg                F_SLastN; 
reg                F_FirstN; 
 
reg    [`FCWIDTH:0]      fcounter; //counter indicates num of data in 

reg    [(`FCWIDTH-1):0]   rd_ptr;      // Current read pointer. 
reg    [(`FCWIDTH-1):0]   wr_ptr;      // Current write pointer. 
wire   [(`FWIDTH-1):0]    FIFODataOut; // Data out from FIFO MemBlk 
wire   [(`FWIDTH-1):0]    FIFODataIn;  // Data into FIFO MemBlk 
 
wire   ReadN  = FOutN; 
wire   WriteN = FInN; 
 
assign F_Data     = FIFODataOut; 
assign FIFODataIn = Data_In; 
 
 
    FIFO_MEM_BLK memblk(.clk(Clk), 
                        .writeN(WriteN), 
                        .rd_addr(rd_ptr), 
                        .wr_addr(wr_ptr), 
                        .data_in(FIFODataIn), 
                        .data_out(FIFODataOut) 
                       ); 
 
 
 
    // Control circuitry for FIFO. If reset or clr signal is asserted, 
    // all the counters are set to 0. If write only the write counter 
    // is incremented else if read only read counter is incremented 
    // else if both, read and write counters are incremented. 
    // fcounter indicates the num of items in the FIFO. Write only 
    // increments the fcounter, read only decrements the counter, and 
    // read && write doesn't change the counter value. 
    always @(posedge Clk or negedge RstN) 
    begin 
 
       if(!RstN) begin 
           fcounter    <= 0; 
           rd_ptr      <= 0; 
           wr_ptr      <= 0; 
       end 
       else begin 
 
           if(!FClrN ) begin 
               fcounter    <= 0; 
               rd_ptr      <= 0; 
               wr_ptr      <= 0; 
           end 
           else begin 
 
               if(!WriteN && F_FullN) 
                   wr_ptr <= wr_ptr + 1; 
 
 
 
 
 
 

               if(!ReadN && F_EmptyN) 
                    rd_ptr <= rd_ptr + 1; 
 
               if(!WriteN && ReadN && F_FullN) 
                   fcounter <= fcounter + 1; 
 
               else if(WriteN && !ReadN && F_EmptyN) 
                   fcounter <= fcounter - 1; 
          end 
       end 
    end 
 
 
 
    // All the FIFO status signals depends on the value of fcounter. 
    // If the fcounter is equal to fdepth, indicates FIFO is full. 
    // If the fcounter is equal to zero, indicates the FIFO is empty. 
 
 
 
    // F_EmptyN signal indicates FIFO Empty Status. By default it is 
    // asserted, indicating the FIFO is empty. After the First Data is 
    // put into the FIFO the signal is deasserted. 
    always @(posedge Clk or negedge RstN) 
    begin 
 
       if(!RstN) 
          F_EmptyN <= 1'b0; 
 
       else begin 
          if(FClrN==1'b1) begin 
 
             if(F_EmptyN==1'b0 && WriteN==1'b0) 
 
                 F_EmptyN <= 1'b1; 
 
             else if(F_FirstN==1'b0 && ReadN==1'b0 && WriteN==1'b1) 
 
                 F_EmptyN <= 1'b0; 
          end 
          else 
             F_EmptyN <= 1'b0; 
       end 
    end 
 
    // F_FirstN signal indicates that there is only one datum sitting 
    // in the FIFO. When the FIFO is empty and a write to FIFO occurs, 
    // this signal gets asserted. 
    always @(posedge Clk or negedge RstN) 
    begin 
 
       if(!RstN) 
 
          F_FirstN <= 1'b1; 
 
       else begin 
          if(FClrN==1'b1) begin 
 
 
 
 
 

 
             if((F_EmptyN==1'b0 && WriteN==1'b0) || 
                (fcounter==2 && ReadN==1'b0 && WriteN==1'b1)) 
 
                 F_FirstN <= 1'b0; 
 
             else if (F_FirstN==1'b0 && (WriteN ^ ReadN)) 
                 F_FirstN <= 1'b1; 
          end 
          else begin 
 
             F_FirstN <= 1'b1; 
          end 
       end 
    end 
 
 
    // F_SLastN indicates that there is space for only two data words 
    //in the FIFO. 
    always @(posedge Clk or negedge RstN) 
    begin 
 
       if(!RstN) 
 
          F_SLastN <= 1'b1; 
 
       else begin 
 
          if(FClrN==1'b1) begin 
 
             if( (F_LastN==1'b0 && ReadN==1'b0 && WriteN==1'b1) || 
                 (fcounter == (`FDEPTH-3) && WriteN==1'b0 && 
ReadN==1'b1)) 
 
                 F_SLastN <= 1'b0; 
 
 
             else if(F_SLastN==1'b0 && (ReadN ^ WriteN) ) 
                 F_SLastN <= 1'b1; 
 
          end 
          else 
             F_SLastN <= 1'b1; 
 
       end 
    end 
 
    // F_LastN indicates that there is one space for only one data 
    // word in the FIFO. 
    always @(posedge Clk or negedge RstN) 
    begin 
 
       if(!RstN) 
 
          F_LastN <= 1'b1; 
 
       else begin 
 
 
 
 

          if(FClrN==1'b1) begin 
 
             if ((F_FullN==1'b0 && ReadN==1'b0)  || 
                 (fcounter == (`FDEPTH-2) && WriteN==1'b0 && 
ReadN==1'b1)) 
 
                 F_LastN <= 1'b0; 
 
             else if(F_LastN==1'b0 && (ReadN ^ WriteN) ) 
                 F_LastN <= 1'b1; 
          end 
          else 
             F_LastN <= 1'b1; 
       end 
    end 
 
 
    // F_FullN indicates that the FIFO is full. 
    always @(posedge Clk or negedge RstN) 
    begin 
 
       if(!RstN) 
 
           F_FullN <= 1'b1; 
 
       else begin 
           if(FClrN==1'b1)  begin 
 
               if (F_LastN==1'b0 && WriteN==1'b0 && ReadN==1'b1) 
 
                    F_FullN <= 1'b0; 
 
               else if(F_FullN==1'b0 && ReadN==1'b0) 
 
                    F_FullN <= 1'b1; 
           end 
           else 
               F_FullN <= 1'b1; 
 
       end 
    end 
 
endmodule
