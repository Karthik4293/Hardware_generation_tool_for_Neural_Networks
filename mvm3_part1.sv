
//Top level module

module mvm3_part1 (clk, reset, s_valid, m_ready, data_in, m_valid, s_ready, data_out, overflow);

       input clk, reset;
       input s_valid, m_ready;
       input signed [7:0] data_in;

       output overflow, s_ready, m_valid;
       output logic signed [15:0] data_out;

       reg [3:0] addr_a;
	     reg [1:0] addr_x, addr_y, addr_z;
       logic wr_en_x, wr_en_a, wr_en_y, wr_en_z;

       always_ff @(posedge clk) begin
          if (reset == 1)
             data_out <= 0;
       end

       datapath d(clk, clear_acc, reset, data_in, addr_x, wr_en_x, addr_a, wr_en_a, data_out, addr_y, wr_en_y, addr_z, wr_en_z, overflow);
       control  c(clk, s_valid, s_ready, m_ready, m_valid, reset, addr_x, wr_en_x, addr_a, wr_en_a, done, clear_acc, addr_y, wr_en_y, addr_z, wr_en_z);

endmodule
//-----------------------------------------------------------------------------

//Control module

module control(clk, s_valid, s_ready, m_ready, m_valid, reset, addr_x, wr_en_x, addr_a, wr_en_a, done, clear_acc, addr_y, wr_en_y, addr_z, wr_en_z);

       input clk, s_valid, reset, s_ready;
       output logic [3:0] addr_a;
	     output logic [1:0] addr_x, addr_y, addr_z;
       output logic done, wr_en_x, wr_en_a, clear_acc, wr_en_y, wr_en_z,m_valid, m_ready;
       logic write_done_x, write_done_a, mac_done, write_done_y, write_done_z;
	     logic [2:0] state, next_state;
	     logic [1:0] multiplier, counter;



       always_ff @(posedge clk) begin

              if (reset == 1)
                   state<=0;
              else
                   state<=next_state;
       end

       always_comb begin

          case (state)               // State explainations

            0 : if (s_valid == 1)               // State 0 checks valid input
                   next_state = 1;
                else
                   next_state = 0;

            1 : if (s_ready == 1)               // State 1 asserts s_ready
                    next_state = 2;
                else
                    next_state = 1;

            2 : if (write_done_x == 1)          // State 2 starts writing into the memory and checks if write is done
                    next_state = 3;
                else
                    next_state = 2;

            3 : if (write_done_a == 1)          // State 3 -- same as above
                    next_state = 4;
                else
                    next_state = 3;

            4 : if (mac_done == 1)              // State 4 starts MAC and respond if completed(values are stored in state 4)
                    next_state = 5;
                else
                    next_state = 4;

            5 : if (done)              // State 5 put the output into a different memory
                    next_state = 0;
                else
                    next_state = 5;
          endcase
       end

       assign wr_en_x = (state == 2);
       assign wr_en_a = (state == 3);
       assign wr_en_y = (((counter==1)|(mac_done==1))&(state==4));
    //   assign m_valid = (addr_y>=0)&(addr_y<=2);

    //   assign display_done = ((state==5)&(addr_y==2)&(entry==1));



       assign write_done_x = ((state==2)&(addr_x==2));
       assign write_done_a = ((state==3)&(addr_a==8));
       assign write_done_y = ((state==4)&(addr_y==2));
       assign write_done_z = ((state==5)&(addr_z==2));



      always_ff @(posedge clk) begin

            if (state == 0) begin
               multiplier <= 0;
               mac_done <= 0;
               counter <= 0;
            end

           else if (state == 1) begin
               addr_a <= 0;
               addr_x <= 0;
            end

            else if (state == 2) begin
                 if (write_done_x == 0)
                     addr_x <= addr_x + 1;
                 else
                     addr_x <= 0;
            end

            else if (state == 3) begin
                 if (write_done_a == 0)
                    addr_a <= addr_a + 1;
                 else
                    addr_a <= 0;
            end

            else if (state == 4) begin
                 if (multiplier<=2) begin
                     if (counter<=2) begin
                        addr_x <= counter;
                        addr_a <= (3 * multiplier) + counter;
                        counter <= counter + 1;
                     end
                     else  begin
                            addr_y <= multiplier;
                            multiplier <= multiplier + 1;
                            counter <= 0;
                            clear_acc <= 1;
                     end
                 end
                 else begin
                     mac_done <= 1;
                     addr_y <= 0;
                     clear_acc <= 1;
                 end
            end

            else if (state == 5) begin
                  if (m_valid & m_ready & (addr_y<=2)) begin
                      addr_y <= addr_z;
                      addr_y <= addr_y + 1;
                  end
                  else
                      done <= 1;
            end
      end
endmodule
//-----------------------------------------------------------------------------

// Datapath module

module datapath(clk, clear_acc, reset, data_in, addr_x, wr_en_x, addr_a, wr_en_a, data_out, addr_y, wr_en_y, addr_z, wr_en_z, overflow);

  input clk, reset, clear_acc;
  input wr_en_x,wr_en_a,wr_en_z, wr_en_y;
  input signed [7:0]data_in;
  input logic [3:0]addr_a;
  input logic [1:0] addr_x,addr_z, addr_y;
  output logic signed [15:0]data_out;
  output logic overflow;

  logic [15:0]f, data_out_temp;
  logic signed [7:0] data_out_x, data_out_a;

  memory #(8,3,2) x(clk, data_in, data_out_x, addr_x, wr_en_x);
  memory #(8,9,4) a(clk, data_in, data_out_a, addr_a, wr_en_a);
  part2_mac m(clk, clear_acc, data_out_a, data_out_x, f, overflow);
  memory #(16,3,2) y(clk, f, data_out_temp, addr_y, wr_en_y);
  memory #(16,3,2) z(clk, data_out_temp, data_out, addr_z, wr_en_z);

endmodule
//-----------------------------------------------------------------------------

//MEMORY MODULE

module memory(clk, data_in, data_out, addr, wr_en);
	parameter WIDTH=8, SIZE=9, LOGSIZE=6;
	input signed [WIDTH-1:0] data_in;
	output logic signed [WIDTH-1:0] data_out;
	input [LOGSIZE-1:0] addr;
	input clk, wr_en;
	logic signed [SIZE-1:0][WIDTH-1:0] mem;
	always_ff @(posedge clk) begin
		data_out <= mem[addr];
		if (wr_en)
			mem[addr] <= data_in;
	end
endmodule

//-----------------------------------------------------------------------------

// MAC module

module part2_mac(clk, clear_acc, a, b, f, overflow);
        input clk, clear_acc;
        input signed [7:0] a, b;
        output logic signed [15:0] f;
        output logic  overflow;


        //internal logic

        logic signed [7:0] ip1, ip2;
        logic signed [15:0] out,mul,add;
        logic overflow_int;


// Conditions on reset
        always_ff @(posedge clk) begin
            if (clear_acc == 1)
                  f <=0;
            else
                  f<=add;
                  overflow <= overflow_int;
        end

        always_comb  begin
                mul = ip1 * ip2;
                add  = mul + f;
        end

//Overflow Detector
        always_ff @(posedge clk)begin

               if(overflow)
                  overflow_int = 1;

               else if ((mul[15] == f[15])&&(add[15] != f[15]))
                   overflow_int <= 1;

               else
                    overflow_int =0;
        end
endmodule

//------------------------------------------------------------------------------
//testbench

module check_timing();

   logic clk, s_valid, s_ready, m_valid, m_ready, reset, overflow;
   logic signed [7:0] data_in;
   logic signed [15:0] data_out;

   initial clk=0;
   always #5 clk = ~clk;

   mvm3_part1 dut(.clk(clk), .reset(reset), .s_valid(s_valid), .m_ready(m_ready),
      .data_in(data_in), .m_valid(m_valid), .s_ready(s_ready), .data_out(data_out),
      .overflow(overflow));


     logic rb, rb2;
      always begin
         @(posedge clk);
         #1;
         std::randomize(rb, rb2); // randomize rb
      end

      logic [7:0] invals[0:11] = '{1, 2, 3, 4, 5, 6, 7, 8, 9, 1, 2, 3};

      logic [15:0] j;

      always_comb begin
         if (s_valid == 1) begin
            data_in = invals[j];
            s_ready = 1;
         end
          else
            data_in = 'x;
      end


      always_comb begin
         if ((j>=0) && (j<12) ) begin
            s_valid=1;
         end
         else
            s_valid=0;
      end

      always @(posedge clk) begin
         if (s_valid && s_ready)
            j <= #1 j+1;
      end

      logic [15:0] i;
      always @* begin
         if ((i>=0) && (i<3) && (rb2==1'b1))
            m_ready = 1;
         else
            m_ready = 0;
      end

      always @(posedge clk) begin
         if (m_ready && m_valid) begin
            $display("y[%d] = %d" , i, data_out);
            i=i+1;
         end
      end

      initial begin

         j = 0;
         m_ready = 0;
         reset = 0;

         // reset
         @(posedge clk); #1; reset = 1;
         @(posedge clk); #1; reset = 0;
         wait(i==3);
         $finish;
      end

      initial begin
         repeat(1000) begin
            @(posedge clk);
         end
         $display("Warning: Output not produced within 1000 clock cycles; stopping simulation so it doens't run forever");
         $stop;
      end

endmodule
