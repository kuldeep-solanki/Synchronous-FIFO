`include "assert_fifo.sv"
`timescale 1ns / 1ps

//////////Transaction Class//////////
class transaction;
rand bit wr_en;
rand bit rd_en;
rand bit [7:0] data_in;
bit [7:0] data_out;
bit full;
bit empty;
                  
//custom copy method
function transaction copy();
transaction new_obj = new();
new_obj.wr_en = this.wr_en;
new_obj.rd_en = this.rd_en;
new_obj.data_in = this.data_in;
new_obj.data_out = this.data_out;
new_obj.full = this.full;
new_obj.empty = this.empty;
return new_obj;
endfunction              
endclass


//////////Generator Class//////////
class generator;
transaction t;
mailbox #(transaction) mbx;
event next;
event done;

//custom constructor
function new( mailbox #(transaction) mbx);
this.mbx = mbx;
t = new(); //calling constructor of transaction class
endfunction

task run();
int n = 0; //To count the test number 
repeat(200)
begin
t.randomize();
mbx.put(t.copy());//sending the copy of transaction class on the mailbox
$display("Test No. : %0d",++n);
$display("[GEN] : Data send to Driver class, wr_en : %0d, rd_en : %0d, data_in : %0d", t.wr_en, t.rd_en, t.data_in);
@(next);//waiting for the triggering of the event next form the driver class
end
->done;//triggering the event done
endtask
endclass



//////////Driver Class//////////
class driver;
transaction t;
mailbox #(transaction) mbx;
virtual FIFO_intf fif;

function new( mailbox #(transaction) mbx);
this.mbx = mbx;
endfunction


//Task Reset
task reset();
fif.rst <= 1'b1;
fif.wr_en <= 1'b0;
fif.rd_en <= 1'b0;
fif.data_in <= 0;
repeat(5) @(posedge fif.clk);//waiting for 5 clk pulses
fif.rst <= 1'b0;
$display("------------------------------------------------------------");
$display("EMPTY : %0d, FULL : %0d",fif.empty,fif.full);
$display("[DRV] : DUT reset done");
$display("------------------------------------------------------------");
endtask 


task run();
forever
begin
mbx.get(t);
@ (posedge fif.clk);
fif.wr_en <= t.wr_en;
fif.rd_en <= t.rd_en;
fif.data_in <= t.data_in;
$display("[DRV] : Interface triggered with wr_en : %0d, rd_en : %0d, data_in : %0d", t.wr_en, t.rd_en, t.data_in);
repeat(2) @ (posedge fif.clk);
end
endtask
endclass


//////////Monitor Class//////////
class monitor;
transaction t;
mailbox #(transaction) mbx;
virtual FIFO_intf fif;

function new (mailbox #(transaction) mbx);
this.mbx = mbx;
endfunction


task run();
t = new();
forever
begin 
repeat(2) @(posedge fif.clk);
t.wr_en = fif.wr_en;
t.rd_en = fif.rd_en;
t.data_in = fif.data_in;
t.full = fif.full;
t.empty = fif.empty;
@(posedge fif.clk); //waiting for one extra clock to collect the response of dout as dut takes one extra clock tick to produce the result
t.data_out = fif.data_out;
mbx.put(t);
$display("[MON] : Data send to scoreboard, Wr_en:%0d rd_en:%0d data_in:%0d data_out:%0d full:%0d empty:%0d", t.wr_en, t.rd_en, t.data_in, t.data_out, t.full, t.empty);
end
endtask
endclass

//////////Scoreboard Class//////////
class scoreboard;
transaction t;
mailbox #(transaction) mbx;
event next;

//Temporary memory
bit [7:0] farr[$];//queue of each location of 8 bit width
bit [7:0] temp;
int error = 0;
  
function new(mailbox #(transaction) mbx);
this.mbx = mbx;
endfunction


task run();
forever 
begin
mbx.get(t);
$display("[SCO] : Data received from monitor, Wr_en:%0d, rd_En:%0d, data_in:%0d, data_out:%0d, full:%0d, empty:%0d", t.wr_en, t.rd_en, t.data_in, t.data_out, t.full, t.empty);
        
if(t.wr_en == 1'b1 && t.rd_en ==1'b0)
begin
    if(t.full == 1'b0)
    begin
    farr.push_front(t.data_in);
    $display("[SCO] : Data stored in the queue : %0d", t.data_in);
    end
    
    else
    begin
    $display("[SCO] : FIFO is full");
    end
end
        
        
else if (t.wr_en == 1'b0 && t.rd_en ==1'b1)
begin
    if(t.empty == 1'b0)
    begin
        temp = farr.pop_back();
            if (t.data_out == temp)
            begin
            $display("[SCO] : Data Matched and the data Read from the FIFO : %0d",temp);
            end
            
            else
            begin
            $display("[SCO]: Data mismatched");
            error++;
            end
    end
            
    else
    begin
    $display("[SCO] : FIFO is empty");
    end              
end


else if (t.wr_en == 1'b1 && t.rd_en ==1'b1)
begin
    if (t.full == 1'b0 && t.empty ==1'b0)//both read and write operation
    begin
    //write operation
    farr.push_front(t.data_in);
    $display("[SCO] : Data stored in the queue : %0d", t.data_in);
            
    //read operation
    temp = farr.pop_back();
        if (t.data_out == temp)
        begin
        $display("[SCO] : Data Matched and the data Read from the FIFO : %0d",temp);
        end
        else
        begin
        $display("[SCO]: Data mismatched, data_out : %0d, temp : %0d",t.data_out, temp);
        error++;
        end
    end
        
    else if (t.full == 1'b0 && t.empty ==1'b1)//only write operation
    begin
    $display("[SCO] : FIFO is empty");
    //write operation
    farr.push_front(t.data_in);
    $display("[SCO] : Data stored in the queue : %0d", t.data_in);
    end
            
    else if (t.full == 1'b1 && t.empty ==1'b0)//only read operation
    begin
    $display("[SCO] : FIFO is full");
    // read operation
    temp = farr.pop_back();
        if (t.data_out == temp)
        begin
        $display("[SCO] : Data Matched and the data Read from the FIFO : %0d",temp);
        end
        else
        begin
        $display("[SCO]: Data mismatched, data_out : %0d, temp : %0d",t.data_out, temp);
        error++;
        end
    end
end 


else
$display("NO OPERATION ");

$display("------------------------------------------------------------");
-> next;
end
endtask                     
endclass




//////////Environment Class//////////
class environment;
generator gen;
driver drv;
monitor mon;
scoreboard sco;

mailbox #(transaction) gdmbx;
mailbox #(transaction) msmbx;

event gsnext;
event done;

virtual FIFO_intf fif;

//custom constructor
function new(mailbox #(transaction) gdmbx, mailbox #(transaction) msmbx);
this.gdmbx = gdmbx;
this.msmbx = msmbx;

gen = new(gdmbx);
drv = new(gdmbx);

mon = new(msmbx);
sco = new(msmbx);

endfunction


task pre_test();
drv.fif = fif;
mon.fif = fif;
    
gen.next = gsnext;
sco.next = gsnext; 

gen.done = done;

drv.reset(); //to reset the dut
endtask


task test();
fork
gen.run();
drv.run();
mon.run();
sco.run();
join_any
endtask


task post_test();
wait(done.triggered);
$display("------------------------------------------------------------");
$display("Error count : %0d", sco.error);
$display("------------------------------------------------------------");
$finish();
endtask


task run();
pre_test();
test();
post_test();
endtask

endclass



//////////Testbench Top//////////
module FIFO_tb;
environment env;
mailbox #(transaction) gdmbx;
mailbox #(transaction) msmbx;
event done;

FIFO_intf fif();
Syn_FIFO DUT(fif.clk, fif.rst, fif.wr_en, fif.rd_en, fif.data_in, fif.data_out, fif.full, fif.empty);


  
//binding assertion check module with dut
bind Syn_FIFO assert_fifo dut2 (fif.clk, fif.rst, fif.wr_en, fif.rd_en, fif.data_in, fif.data_out, fif.full, fif.empty);


initial
begin
fif.clk = 0;
end

always #5 fif.clk = ~fif.clk;

initial 
begin
gdmbx = new();
msmbx = new();
      
env = new(gdmbx, msmbx);
env.fif = fif;
env.run();
end


  
  ////////////// Functional Coverage ///////////////////////
  covergroup c @(posedge fif.clk);//sampling the coverage data at each posedge of clock
  option.per_instance = 1;
  option.name = "FIFO";
  
  coverpoint fif.rst{
    bins rst_low = {0};
    bins rst_high = {1};
   }
  
  coverpoint fif.wr_en {
    bins wr_low = {0};
    bins wr_high = {1};
  }

  coverpoint fif.rd_en {
    bins rd_low = {0};
    bins rd_high = {1};
  }
  
  coverpoint fif.empty {
    bins empty_low = {0};
    bins empty_high = {1};
  }

  coverpoint fif.full {
    bins full_low = {0};
    bins full_high = {1};
  }
  
  coverpoint fif.data_in {
    bins lower = {[0:80]};
    bins mid = {[81:170]};
    bins higher = {[171:255]};
  }

  coverpoint fif.data_out {
    bins lower = {[0:80]};
    bins mid = {[81:170]};
    bins higher = {[171:255]};
  }
    

  coverpoint DUT.wr_ptr {
    bins lower = {[0:5]};
    bins mid = {[6:10]};
    bins higher = {[11:15]};
  }

  coverpoint DUT.rd_ptr {
 bins lower = {[0:5]};
    bins mid = {[6:10]};
    bins higher = {[11:15]};
  }

  
// To analyse write operation under normal condition
  cross_rst_wr : cross fif.rst, fif.wr_en {
    ignore_bins unused_rst = binsof (fif.rst) intersect {1};
    ignore_bins unused_wr = binsof (fif.wr_en) intersect {0};
  }
  
// To analyse read operation under normal condition
  cross_rst_rd : cross fif.rst, fif.rd_en {
    ignore_bins unused_rst = binsof (fif.rst) intersect {1};
    ignore_bins unused_rd = binsof (fif.rd_en) intersect {0};
  }
  
// To analyse write operation must exercised for all the ranges of din during noraml condition
  cross_rst_wr_din : cross fif.rst, fif.wr_en, fif.data_in {
    ignore_bins unused_rst = binsof (fif.rst) intersect {1};
    ignore_bins unused_wr = binsof (fif.wr_en) intersect {0};
  }

// To analyse read operation must exercised for all the ranges of dout during noraml condition
  cross_rst_rd_dout : cross fif.rst, fif.rd_en , fif.data_out {
    ignore_bins unused_rst = binsof (fif.rst) intersect {1};
    ignore_bins unused_rd = binsof (fif.rd_en) intersect {0};
  }


//To analyse FIFO should be completely filled at least once during the write operation and completely empty during the read operation
  
  cross_wr_full : cross fif.rst, fif.wr_en, fif.full {
    ignore_bins unused_rst = binsof (fif.rst) intersect {1};
    ignore_bins unused_wr = binsof (fif.wr_en) intersect {0};
    ignore_bins unused_full = binsof (fif.full) intersect {0};
  }
  
  cross_rd_empty : cross fif.rst, fif.rd_en, fif.empty {
    ignore_bins unused_rst = binsof (fif.rst) intersect {1};
    ignore_bins unused_rd = binsof (fif.rd_en) intersect {0};
    ignore_bins unused_empty = binsof (fif.empty) intersect {0};
  }
  
endgroup

  
//instance of covergroup c
c ci = new();



initial
begin
$assertvacuousoff(0);
end
endmodule
