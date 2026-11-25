`timescale 1ns/1ps

interface apb_if #(parameter ADDR_WIDTH = 4, parameter DATA_WIDTH = 32)(
  input logic pclk
);
  logic presetn;
  logic pready;
  logic psel;
  logic penable;
  logic [ADDR_WIDTH-1:0]paddr;
  logic [DATA_WIDTH-1:0]pwdata;
  logic [DATA_WIDTH-1:0]prdata;
  logic pwrite;
  logic pslverr;
endinterface


class apb_transaction;
  logic pwrite;
  logic [3:0]paddr;
  logic [31:0]pwdata;
  logic [31:0]prdata;
  
  function void do_randomize(bit force_write = 0, bit force_read = 0);
    if(force_write) pwrite = 1'b1;
    else if(force_read) pwrite = 1'b0;
    else pwrite = 1'($urandom_range(1, 0));
    paddr = $urandom_range(0, 15);
    pwdata = $urandom();
  endfunction
endclass

class apb_scoreboard;
  logic [31:0] ref_mem[0:15]= '{default: 32'h0000_0000};
  int pass_count = 0;
  int fail_count = 0;
  
  function void check_transaction(apb_transaction tr);
    logic [31:0] expected_data;
    
    if(tr.pwrite) begin
      ref_mem[tr.paddr] = tr.pwdata;
      $display("WRITE] addr: 0x%h | [WROTE] data: 0x%08h", tr.paddr, tr.pwdata);
    end else begin
      expected_data = ref_mem[tr.paddr];
      if(tr.prdata == expected_data) begin
        pass_count++;
        $display("[PASS] Addr 0x%h | Expected 0x%08h | Actual 0x%08h", tr.paddr, expected_data, tr.prdata);
      end else begin
        fail_count++;
        $display("[FAIL] addr 0x%h | Expected 0x%08h | Actual 0x%08h", tr.paddr, expected_data, tr.prdata);
      end
    end
  endfunction
  function void report();
    $display("\n==========================================");
    $display(" AMBA APB3 VERIFICATION REPORT");
    $display(" TOTAL READ CHECKS PASSED: %0d | FAILED: %0d", pass_count, fail_count);
    $display("==========================================\n");
  endfunction
endclass

class apb_coverage;
  bit write_hits[0:15] = '{default: 1'b0};
  bit read_hits[0:15] = '{default : 1'b0};
  
  function void sample_tr(apb_transaction tr);
    if(tr.pwrite)
      write_hits[tr.paddr] = 1'b1;
    else
      read_hits[tr.paddr] = 1'b1;
  endfunction
  
  function real get_coverage();
    int total_hits = 0;
    for(int i=0; i<16; i++) begin
      if(write_hits[i]) total_hits++;
      if(read_hits[i]) total_hits++;
    end
    return (real'(total_hits)/ 32.0) * 100.0;
  endfunction   
endclass

module testbench;
  logic pclk;
  
  initial begin
    pclk = 1'b0;
    forever #5ns pclk = ~pclk;
  end
  
  apb_if #(4, 32) intf(pclk);
  
   apb_slave #(.ADDR_WIDTH(4), .DATA_WIDTH(32)) u_dut (
        .pclk(intf.pclk),       .presetn(intf.presetn),
        .psel(intf.psel),       .penable(intf.penable),
        .pwrite(intf.pwrite),   .paddr(intf.paddr),
        .pwdata(intf.pwdata),   .prdata(intf.prdata),
        .pready(intf.pready),   .pslverr(intf.pslverr)
    );
  apb_scoreboard sb;
  apb_coverage cov;
  
  task automatic drive_apb_transfer(apb_transaction tr);
    @(posedge pclk);
    #1ps;
    intf.psel = 1'b1;
    intf.penable = 1'b0;
    intf.paddr = tr.paddr;
    intf.pwdata = tr.pwdata;
    intf.pwrite = tr.pwrite;
    
    @(posedge pclk);
    #1ps;
    
    intf.penable = 1'b1;
    
    @(posedge pclk);
    while(!intf.pready) begin
      @(posedge pclk);
    end
    
    if(!tr.pwrite) begin
      tr.prdata = intf.prdata;
    end
    
    sb.check_transaction(tr);
    cov.sample_tr(tr);
    
    #1ps;    
    intf.psel = 1'b0;
    intf.penable = 1'b0;
    @(posedge pclk);
  endtask
  
  initial begin
    apb_transaction tr;
    sb = new();
    cov = new();
    
    intf.presetn = 1'b0;
    intf.psel = 1'b0;
    intf.penable = 1'b0;
    intf.paddr = 4'h00;
    intf.pwrite = 1'b0;
    intf.pwdata = 32'h00;
    
    #20ns;
    intf.presetn = 1'b1;
    #10ns;
    
    for(int addr = 0; addr< 16; addr++) begin
      tr = new();
      tr.do_randomize(.force_write(1));
      tr.paddr = 4'(addr);
      drive_apb_transfer(tr);
    end
    
    repeat (80) begin
      tr =  new();
      tr.do_randomize();
      drive_apb_transfer(tr);
    end
    
    #20ns;
    sb.report();
    $display("==========================================");
    $display(" FUNCTIONAL COVERAGE: %0.2f%% (32 Cross bins)", cov.get_coverage());
    $display("==========================================\n");
    $finish;
  end
  
  property p_penable_requires_psel;
    @(posedge pclk) disable iff (!intf.presetn) 
    intf.penable |-> intf.psel;
  endproperty
  assert property (p_penable_requires_psel)
    else $error("[SVA APB FAIL] penable asserted without psel");
    
    property p_setup_to_access;
      @(posedge pclk) disable iff (!intf.presetn)
      (intf.psel && !intf.penable) |=> (intf.psel && intf.penable);
    endproperty
    assert property (p_setup_to_access)
      else $error("[SVA APB FAIL] setup to access failed");
      
      property p_addr_ctrl_stable;
        @(posedge pclk) disable iff (!intf.presetn)
        (intf.psel && !intf.penable) |=> ($stable(intf.paddr) && $stable(intf.pwrite));
      endproperty
      assert property (p_addr_ctrl_stable)
        else $error("[SVA APB FAIL] paddr and pwrite not stable when setup tp access");
        
        initial begin
          #10000ns;
          $display("[ERROR] Simualtion Timeout");
          $finish;
        end
        endmodule
      
