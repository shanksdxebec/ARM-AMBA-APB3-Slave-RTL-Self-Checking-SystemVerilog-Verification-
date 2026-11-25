module apb_slave #(
  parameter ADDR_WIDTH = 4,
  parameter DATA_WIDTH = 32
)(
  input wire pclk,
  input wire psel,
  input wire penable,
  input wire [ADDR_WIDTH-1:0]paddr,
  input wire [DATA_WIDTH-1:0]pwdata,
  input wire presetn,
  input wire pwrite,
  output wire [DATA_WIDTH-1:0]prdata,
  output reg pready,
  output reg pslverr
);
  reg [DATA_WIDTH-1:0] reg_file[ 0: 15];
  typedef enum logic [1:0] {
    IDLE   = 2'b00,
    SETUP  = 2'b01,
    ACCESS = 2'b10
  } apb_state_t;
  apb_state_t state, next_state;
  
  assign pslverr= 1'b0;
  assign prdata = (psel && penable && !pwrite) ? reg_file[paddr] : {DATA_WIDTH{1'b0}};
  
  always@(posedge pclk or negedge presetn) begin
    if(!presetn)
      state<=IDLE;
    else
      state<=next_state;
  end
  
  always@(*) begin
    case(state)
      IDLE: begin
        if(psel && !penable)
          next_state<= SETUP;
        else
          next_state<=IDLE;
      end
      
      SETUP: begin
        if(psel && penable)
          next_state<= ACCESS;
        else if(!psel)
          next_state<= IDLE;
        else
          next_state<= SETUP;
      end
      
      ACCESS: begin
        if(psel && !penable)
          next_state<= SETUP;
        else
          next_state<=  IDLE;
      end
      
      default: next_state<= IDLE;
    endcase
  end
  
  integer i;
  always@(posedge pclk or negedge presetn) begin
    if(!presetn) begin 
      pready<=1'b0;
      for( i=0; i<(1<<ADDR_WIDTH); i=i+1) begin
        reg_file[i]<={DATA_WIDTH{1'b0}};
      end
    end else begin
      case(next_state)
        IDLE: begin
          pready<= 1'b0;
        end
        
        SETUP: begin
          pready<= 1'b0;
        end
        
        ACCESS: begin
          pready<= 1'b1;
          if(pwrite) begin
            reg_file[paddr]<= pwdata;
          end
        end
      endcase
    end
  end
endmodule
            
