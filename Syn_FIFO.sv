`timescale 1ns / 1ps

module Syn_FIFO(clk,rst, wr_en, rd_en, data_in, data_out, full, empty);
input clk;
input rst;
input wr_en;
input rd_en;
input [7:0] data_in;
output reg[7:0] data_out=0;//initializes the output to 0
output reg full =0, empty=1;



//Internal Registers
reg [3:0] wr_ptr = 1'b0;
reg [3:0] rd_ptr = 1'b0;
reg [4:0] count = 1'b0; //To count 16 locations of FIFO
reg [7:0] FIFO_Mem [15:0]; //FIFO Memory



// setting the full and empty flag

always@ (count)
begin
full = (count == 16) ? 1'b1 : 1'b0;
empty = (count == 0) ? 1'b1 : 1'b0;
end



//write process
always@ (posedge clk or posedge rst)
if (rst == 1'b1)
begin
wr_ptr <= 1'b0;
end

else if ( (wr_en == 1'b1) && (!full) )
begin
FIFO_Mem [wr_ptr] <= data_in;
data_out <= 0;
wr_ptr <= wr_ptr+1;
end



//Read Process
always@ (posedge clk, posedge rst)
if (rst == 1'b1)
begin
rd_ptr <= 0;
data_out <=0;
end

else if ((rd_en == 1'b1) && (!empty) )
begin
data_out <= FIFO_Mem [rd_ptr];
rd_ptr <= rd_ptr+1;
end



//Counter 
always@ (posedge clk, posedge rst)
if (rst == 1'b1 )
begin
count <= 5'd0;
end

else 
begin
case ( {wr_en, rd_en} )
2'b00 : count <= count;//No operation
2'b01 : count <= (empty) ? count : count-1;//only resd operation
2'b10 : count <= (full) ? count : count+1;//only write operation
2'b11 : begin
        if (full == 0 && empty == 0)  count <= count;
        else if (full == 0 && empty == 1) count <= count+1;
        else if (full == 1 && empty == 0) count <= count-1;
        end 
//count <= count; //both read and write operation at the same time
default : count <= count;
endcase
end

endmodule



interface FIFO_intf;
logic clk;
logic rst;
logic wr_en;
logic rd_en;
logic [7:0] data_in;
logic [7:0] data_out;
logic full;
logic empty;
endinterface
