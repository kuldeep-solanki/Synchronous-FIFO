//////////assertion check module/////////
module assert_fifo (clk,rst,wr,rd,din,dout,full, empty);
input clk, rst, wr, rd;
input [7:0] din;
input [7:0] dout;
input empty, full;  
 
  
//1. checking the status of full and empty flag when rst asserted
////checking on edge
  
RST_1: assert property(@(posedge clk) $rose(rst) |-> (full==1'b0 && empty==1'b1) );  
  
/////checking on level
RST_2: assert property(@(posedge clk) rst |-> (full==1'b0 && empty==1'b1));
  
  
//2. cheecking the operation of full and empty flag
     
  Full_1: assert property (@(posedge clk) disable iff(rst) (Syn_FIFO.count==16)|-> full);   
  
    Full_2: assert property (@(posedge clk) disable iff(rst) $rose(full)|=>($stable(Syn_FIFO.wr_ptr) or (Syn_FIFO.wr_ptr ==0 ))[*1:$] ##1 !full);
  
      EMPTY_1: assert property (@(posedge clk) disable iff(rst) (Syn_FIFO.count == 0) |-> empty); 
     
        EMPTY_2:  assert property (@(posedge clk) disable iff(rst) $rose(empty) |=> ($stable(Syn_FIFO.rd_ptr) or (Syn_FIFO.rd_ptr ==0 ))[*1:$] ##1 !empty);
       
 
  
//3.Write+Read pointer behavior with rd and wr signal
 
//if wr is high and full is low, wptr must incr
  WPTR1: assert property (@(posedge clk)  !rst && wr && !full |=> $changed(Syn_FIFO.wr_ptr));
         
// if wr is low, wptr must constant
    WPTR2: assert property (@(posedge clk) !rst && !wr |=> $stable(Syn_FIFO.wr_ptr));
    
         
//if rd is high and empty is low, rptr must incr
        RPTR1: assert property (@(posedge clk)  !rst && rd && !empty |=> $changed(Syn_FIFO.rd_ptr));

// if rd is low, rptr must constant
          RPTR2: assert property (@(posedge clk) !rst && !rd |=> $stable(Syn_FIFO.rd_ptr));

  
      
              
//4. state of all the i/o ports for all clock edge
//using immediate assertion statement inside the always block for all input output ports
  always@(posedge clk)
    begin
      assert final (!$isunknown(dout));
      assert final (!$isunknown(rst));
      assert final (!$isunknown(wr));
      assert final (!$isunknown(rd));
      assert final (!$isunknown(din));
    end
            
            
///5. Data must match
property p1;
integer waddr,raddr;//local variables
logic [7:0] data1,data2;

  
  (wr, waddr = Syn_FIFO.wr_ptr, data1 = din) |-> ##[1:$] (rd,raddr=Syn_FIFO.rd_ptr,data2= dout) ##0 (waddr == raddr-1)##0(data1==data2);
endproperty

A1: assert property ( @(posedge clk) disable iff(rst) p1);
  
  
//6. Ensure data_out is 0 after reset
DATA_AFTER_RESET: assert property (@(posedge clk) rst |-> (dout == 0));

  
//7. Write pointer wraps around correctly
WPTR_WRAP: assert property (@(posedge clk) disable iff(rst) (wr && !full && Syn_FIFO.wr_ptr == 15) |-> ##1 (Syn_FIFO.wr_ptr == 0)) ;

//8. Read pointer wraps around correctly
RPTR_WRAP: assert property (@(posedge clk) disable iff(rst) (rd && !empty && Syn_FIFO.rd_ptr == 15) |-> ##1 (Syn_FIFO.rd_ptr == 0));


endmodule
