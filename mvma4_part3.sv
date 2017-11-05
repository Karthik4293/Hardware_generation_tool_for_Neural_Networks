
//Top level module

module mvma4_part3 (clk, reset, s_valid, m_ready, data_in, m_valid, s_ready, data_out, overflow);

       input clk, reset;
       input s_valid, m_ready;
       input signed [7:0] data_in;

       output overflow, s_ready, m_valid;
       output logic signed [15:0] data_out;

       logic [3:0] addr_a;
	     logic [1:0] addr_x, addr_y, addr_z, addr_b;
       logic wr_en_x, wr_en_a, wr_en_y,clear_acc, overflow_temp, wr_en_z, of, valid_in, valid_out;
       logic signed [15:0] d_out,data_out_temp;

       datapath d(clk, clear_acc, reset, data_in, addr_x, wr_en_x, addr_b, wr_en_b, addr_a, wr_en_a, d_out, data_out_temp, addr_y, wr_en_y, overflow_temp, of, wr_en_z, addr_z, valid_in, valid_out);
       control  c(clk, s_valid, s_ready, m_ready, m_valid, reset, addr_x, wr_en_x, addr_b, wr_en_b, addr_a, wr_en_a, clear_acc, addr_y, wr_en_y, valid_in, valid_out, data_out_temp, data_out, wr_en_z, addr_z, overflow, of);

endmodule
//-----------------------------------------------------------------------------

//Control module

module control(clk, s_valid, s_ready, m_ready, m_valid, reset, addr_x, wr_en_x, addr_b, wr_en_b, addr_a, wr_en_a, clear_acc, addr_y, wr_en_y, valid_in, valid_out, data_out_temp, data_out, wr_en_z, addr_z, overflow, of);

       input clk, s_valid, reset, m_ready, valid_out, of;
       output logic [3:0] addr_a;
	     output logic [1:0] addr_x, addr_y, addr_z, addr_b;
       input logic [15:0] data_out_temp;
       output logic[15:0] data_out;
       output logic wr_en_x, wr_en_a, wr_en_b, clear_acc, wr_en_y, m_valid, s_ready, valid_in, overflow, wr_en_z;
       logic write_done_x, write_done_a, write_done_b, mac_done, read_done_y,read_done_z, c,dummy;
	     logic [2:0] state, next_state, multiplier, counter;
	//s     logic [1:0] ;


       always_ff @(posedge clk) begin

              if (reset == 1) begin
                    state<=0;
              end

              else
                   state<=next_state;
       end

       always_comb begin

          case (state)                          // State explainations

             0 : if (s_valid == 1)              // State 0 checks valid input and reset state
                   next_state = 1;
                else
                   next_state = 0;

            1 : if (write_done_a == 1)          // State 1 starts writing matrix into the memory and checks if write is done
                    next_state = 2;
                else
                    next_state = 1;

            2 : if (write_done_b == 1)         // State 2 -- writes the vector
                    next_state = 3;
                else
                    next_state = 2;

            3 : if (write_done_x == 1)          // State 2 -- writes the vector
                    next_state = 4;
                else
                    next_state = 3;

            4 : if (mac_done == 1)              // State 3 starts MAC and respond if completed(values are stored in state 4)
                    next_state = 5;
                else
                    next_state = 4;

            5 : if ((read_done_y == 1) && (read_done_z == 1))             // State 4 reads the output from the memory
                    next_state = 0;
                else
                    next_state = 5;
          endcase
       end

     // writing to memory -- write enable signals
       assign wr_en_a = (state == 1)&(s_valid)&(s_ready);
       assign wr_en_b = (state == 2)&(s_valid)&(s_ready);
       assign wr_en_x = (state == 3)&(s_valid)&(s_ready);

       always_ff @(posedge clk) begin
                    wr_en_y <= ((clear_acc==1)&(valid_out==1));
                    wr_en_z <= ((clear_acc==1)&(valid_out==1));
                   end

     // valid signals -- for checking the validity (AXI)
       assign valid_in = (state == 4);
       assign s_ready = ((state == 1) | (state == 2) | (state ==3));
       assign clear_acc =  (mac_done == 1) | (counter == 1);


    //  Read and write asserting signals
       assign write_done_a = ((state==1) && (addr_a == 15 )&&(s_valid)&&(s_ready));
       assign write_done_b = ((state==2) && (addr_b == 3)&&(s_valid)&&(s_ready));
       assign write_done_x = ((state==3) && (addr_x == 3)&&(s_valid)&&(s_ready));
       assign read_done_y = ((state==5) && (addr_y==3) && (m_valid) && (m_ready));
       assign read_done_z = ((state==5) && (addr_z==3) && (m_valid) && (m_ready));

    // Output assignments
       assign data_out = (state == 5) ? data_out_temp : 0 ;
       assign overflow = (state == 5) ? of : 0 ;




       always_ff @(posedge clk) begin

           if (state == 0) begin
                multiplier <= 0;
                mac_done <= 0;
                counter <= 0;
                addr_y <= 0;
                addr_x <= 0;
                addr_a <= 0;
                addr_z <= 0;
                addr_b <= 0;
                c <= 0;
                dummy <=0;
            end

            else if (state == 1) begin
               if ((write_done_a == 0) && (s_ready) && (s_valid))
                     addr_a <= addr_a + 1;
            end

            else if (state == 2) begin
                 if ((write_done_b == 0) && (s_ready) && (s_valid))
                     addr_b <= addr_b + 1;
                 else if ( write_done_b == 1)
                      addr_b <= 0;
            end

            else if (state == 3) begin
                 if ((write_done_x == 0) && (s_ready) && (s_valid))
                     addr_x <= addr_x + 1;
            end

            else if (state == 4) begin
                 if (multiplier < 4)  begin
                     if (counter < 4) begin
                        addr_a <= ((4 * multiplier) + counter);
                        addr_x <= counter;
                        counter <= (counter + 1);
                     end
                     else  begin
                            addr_y <= multiplier;
                            addr_z <= multiplier;
                            addr_b <= addr_b + 1;
                            multiplier <= multiplier + 1;
                            counter <= 0;
                     end
                 end
                 else begin
                     mac_done <= 1;
                     dummy <= 1;
                 end
            end

            else if (state == 5) begin
                      mac_done <= 0;

                      if (c==1)begin
                        m_valid <= 1;
                        c <= 0;
                      end
                      else if (c == 0) begin
                         m_valid <=0;
                         c <= 1;
                      end

                      if (dummy == 1) begin
                          addr_y <= 0;
                          addr_z <= 0;
                          dummy <= 0;
                      end
                      else if ((m_valid==1) & (m_ready==1)) begin
                               addr_y <= addr_y + 1 ;
                               addr_z <= addr_z + 1 ;
                      end
            end
       end

endmodule
//-----------------------------------------------------------------------------

// Datapath module

module datapath(clk, clear_acc, reset, data_in, addr_x, wr_en_x, addr_b, wr_en_b, addr_a, wr_en_a, d_out, data_out_temp, addr_y, wr_en_y, overflow_temp, of, wr_en_z, addr_z, valid_in, valid_out);

  input clk, reset, clear_acc;
  input wr_en_x,wr_en_a, wr_en_y, wr_en_z, valid_in, wr_en_b;
  input signed [7:0]data_in;
  input logic [3:0]addr_a;
  input logic [1:0] addr_x, addr_y, addr_z, addr_b;
  output logic signed [15:0] d_out,data_out_temp;
  output logic overflow_temp, valid_out, of;

//  logic signed [15:0] data_out_temp;
  logic signed [7:0] data_out_x, data_out_a, data_out_b;


  memory #(8,4,2) x(clk, data_in, data_out_x, addr_x, wr_en_x);
  memory #(8,16,4) a(clk, data_in, data_out_a, addr_a, wr_en_a);
  memory #(8,4,2) b(clk, data_in, data_out_b, addr_b, wr_en_b);
  part2_mac m(clk, clear_acc, data_out_a, data_out_x, data_out_b, d_out, valid_in, valid_out, overflow_temp);
  memory #(16,4,2) y(clk, d_out, data_out_temp, addr_y, wr_en_y);
  memory #(1,4,2) z(clk, overflow_temp, of, addr_z, wr_en_z);


endmodule
//-----------------------------------------------------------------------------

//MEMORY MODULE

module memory(clk, data_in, data_out, addr, wr_en);
      parameter WIDTH=16, SIZE=64, LOGSIZE=6;
      input signed [WIDTH-1:0] data_in;
      output logic signed [WIDTH-1:0] data_out;
      input [LOGSIZE-1:0] addr;
      input clk, wr_en;
      logic [SIZE-1:0][WIDTH-1:0] mem;

      always_ff @(posedge clk) begin
           data_out <= mem[addr];
           if (wr_en)
               mem[addr] <= data_in;
      end
endmodule

//-----------------------------------------------------------------------------

// MAC module

module part2_mac(clk, clear_acc, a, b, c, d_out, valid_in, valid_out, overflow_temp);
        input clk, clear_acc, valid_in;
        input signed [7:0] a, b, c;
        output logic signed [15:0] d_out;
        output logic valid_out, overflow_temp;

        //internal logic

        logic signed [7:0] ip1, ip2;
        logic signed [15:0] out,mul,add, f;
        logic enable_f, enable_ab, overflow_int,overflow_var;


// Conditions on reset
        always_ff @(posedge clk) begin

              if (clear_acc == 1 ) begin
                        ip1 <= 0;
                        ip2 <= 0;
                        f <= c;
                        d_out <= add;
                        overflow_var <= 0;
              end

              else  begin
                  if (enable_ab) begin
                        ip1 <= a;
                        ip2 <= b;
                  end
                  if ((enable_f)) begin
                        f <= add;
                  end
             end
         end

         always_ff @(posedge clk) begin
             if ((valid_out)&(clear_acc)) begin
                overflow_temp <= overflow_int;
             end
         end

//MAC calculation

       assign enable_ab = valid_in;

        always_comb  begin
                mul = ip1 * ip2;
                add  = mul + f;
        end

//Assigning enable_f and determining valid_out

        always_ff @(posedge clk)begin

               if(clear_acc == 1)begin
                    valid_out <= 0 ;
                    enable_f <= 0;
               end

               else begin
                    enable_f <= enable_ab;
                    valid_out <= enable_f ;

               end
        end

//Overflow Detector

      always_ff @ (posedge clk) begin

               if (overflow_var)
                   overflow_int = 1;

               else if ((mul[15] == f[15])&&(add[15] != f[15]))
                   overflow_int = 1;

               else
                    overflow_int =0;
        end



endmodule

//------------------------------------------------------------------------------
module check_timing();

   logic clk, s_valid, s_ready, m_valid, m_ready, reset, overflow;
   logic signed [7:0] data_in;
   logic signed [15:0] data_out;

   initial clk=0;
   always #5 clk = ~clk;

   mvma4_part3 dut(.clk(clk), .reset(reset), .s_valid(s_valid), .m_ready(m_ready),
      .data_in(data_in), .m_valid(m_valid), .s_ready(s_ready), .data_out(data_out),
      .overflow(overflow));


     logic rb, rb2;
      always begin
         @(posedge clk);
         #1;
        void'(std::randomize(rb, rb2)); // randomize rb
      end

      logic [7:0] invals[0:71] = '{1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 1, 2, 3, 4, 3, 4, 5, 6,
      1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 5, 6, 7, 8, 3, 4, 5, 6,
      1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 9, 10, 11, 12, 3, 4, 5, 6};

      logic [15:0] j;

      always @* begin
         if (s_valid == 1) begin
            data_in = invals[j];
          end
         else
            data_in = 'x;
      end


      always_comb begin
         if ((j>=0) && (j<72) && (rb==1'b1)) begin
            s_valid=1;
         end
         else
            s_valid=0;
      end

      always @(posedge clk) begin
         if (s_valid && s_ready)begin
            j <= #1 j+1;
            end
      end

    logic [15:0] i;
    always @* begin
         if ((i>=0) && (i<45) && (rb2==1'b1)) begin
            m_ready = 1;
        end
         else begin
            m_ready = 0;
        end
      end



      always @(posedge clk) begin
         if (m_ready && m_valid) begin
            $display("y = %d" , data_out);
            i=i+1;
         end
      end

      initial begin

         j = 0;
         i=0;
         m_ready = 0;
         reset = 0;

         // reset
         @(posedge clk); #1; reset = 1;
         @(posedge clk); #1; reset = 0;
         wait(i==9);
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
