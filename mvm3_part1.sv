
//Top level module

module mvm3_part1 (clk, reset, s_valid, m_ready, data_in, m_valid, s_ready, data_out, overflow);

       input clk, reset;
       input s_valid, m_ready;
       input signed [7:0] data_in;

       output overflow, s_ready, m_valid;
       output logic signed [15:0] data_out;

       logic [3:0] addr_a;
	     logic [1:0] addr_x, addr_y, addr_z;
       logic wr_en_x, wr_en_a, wr_en_y,clear_acc, overflow_temp, wr_en_z,of;
       logic signed [15:0] d_out,data_out_temp;

       datapath d(clk, clear_acc, reset, data_in, addr_x, wr_en_x, addr_a, wr_en_a, d_out, data_out_temp, addr_y, wr_en_y, overflow_temp, of, wr_en_z, addr_z, valid_in, valid_out);
       control  c(clk, s_valid, s_ready, m_ready, m_valid, reset, addr_x, wr_en_x, addr_a, wr_en_a, clear_acc, addr_y, wr_en_y, valid_in, valid_out, data_out_temp, data_out, wr_en_z, addr_z, overflow, of);

endmodule
//-----------------------------------------------------------------------------

//Control module

module control(clk, s_valid, s_ready, m_ready, m_valid, reset, addr_x, wr_en_x, addr_a, wr_en_a, clear_acc, addr_y, wr_en_y, valid_in, valid_out, data_out_temp, data_out, wr_en_z, addr_z, overflow, of);

       input clk, s_valid, reset, m_ready, valid_out, of;
       output logic [3:0] addr_a;
	     output logic [1:0] addr_x, addr_y, addr_z;
       input logic [15:0] data_out_temp;
       output logic[15:0] data_out;
       output logic wr_en_x, wr_en_a, clear_acc, wr_en_y, m_valid, s_ready, valid_in, overflow, wr_en_z;
       logic write_done_x, write_done_a, mac_done, read_done_y,read_done_z, c,dummy;
	     logic [2:0] state, next_state;
	     logic [1:0] multiplier, counter;


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

            2 : if (write_done_x == 1)          // State 2 -- writes the vector
                    next_state = 3;
                else
                    next_state = 2;

            3 : if (mac_done == 1)              // State 3 starts MAC and respond if completed(values are stored in state 4)
                    next_state = 4;
                else
                    next_state = 3;

            4 : if ((read_done_y == 1) && (read_done_z == 1))             // State 4 reads the output from the memory
                    next_state = 0;
                else
                    next_state = 4;
          endcase
       end

     // writing to memory -- write enable signals
       assign wr_en_a = (state == 1)&(s_valid)&(s_ready);
       assign wr_en_x = (state == 2)&(s_valid)&(s_ready);

       always_ff @(posedge clk) begin
                    wr_en_y <= ((clear_acc==1)&(valid_out==1));
                    wr_en_z <= ((clear_acc==1)&(valid_out==1));
                   end

     // valid signals -- for checking the validity (AXI)
       assign valid_in = (state == 3);
       assign s_ready = ((state == 1) | (state == 2));
       assign clear_acc =  (mac_done == 1) | (counter == 1);


    //  Read and write asserting signals
       assign write_done_a = ((state==1) && (addr_a == 8 )&&(s_valid)&&(s_ready));
       assign write_done_x = ((state==2) && (addr_x == 2)&&(s_valid)&&(s_ready));
       assign read_done_y = ((state==4) && (addr_y==2) && (m_valid) && (m_ready));
       assign read_done_z = ((state==4) && (addr_z==2) && (m_valid) && (m_ready));

    // Output assignments
       assign data_out = (state == 4) ? data_out_temp : 0 ;
       assign overflow = (state == 4) ? of : 0 ;




       always_ff @(posedge clk) begin

           if (state == 0) begin
                multiplier <= 0;
                mac_done <= 0;
                counter <= 0;
                addr_y <= 0;
                addr_x <= 0;
                addr_a <= 0;
                addr_z <= 0;
                c <= 0;
                dummy <=0;
            end

            else if (state == 1) begin
               if ((write_done_a == 0) && (s_ready) && (s_valid))
                     addr_a <= addr_a + 1;
            end

            else if (state == 2) begin
                 if ((write_done_x == 0) && (s_ready) && (s_valid))
                     addr_x <= addr_x + 1;
            end

            else if (state == 3) begin
                 if (multiplier < 3)  begin
                     if (counter < 3) begin
                        addr_a <= ((3 * multiplier) + counter);
                        addr_x <= counter;
                        counter <= (counter + 1);
                     end
                     else  begin
                            addr_y <= multiplier;
                            addr_z <= multiplier;
                            multiplier <= multiplier + 1;
                            counter <= 0;
                     end
                 end
                 else begin
                     mac_done <= 1;
                     dummy <= 1;
                 end
            end

            else if (state == 4) begin
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

module datapath(clk, clear_acc, reset, data_in, addr_x, wr_en_x, addr_a, wr_en_a, d_out, data_out_temp, addr_y, wr_en_y, overflow_temp, of, wr_en_z, addr_z, valid_in, valid_out);

  input clk, reset, clear_acc;
  input wr_en_x,wr_en_a, wr_en_y, wr_en_z, valid_in;
  input signed [7:0]data_in;
  input logic [3:0]addr_a;
  input logic [1:0] addr_x, addr_y, addr_z;
  output logic signed [15:0] d_out,data_out_temp;
  output logic overflow_temp, valid_out, of;

//  logic signed [15:0] data_out_temp;
  logic signed [7:0] data_out_x, data_out_a;


  memory #(8,3,2) x(clk, data_in, data_out_x, addr_x, wr_en_x);
  memory #(8,9,4) a(clk, data_in, data_out_a, addr_a, wr_en_a);
  part2_mac m(clk, clear_acc, data_out_a, data_out_x, d_out, valid_in, valid_out, overflow_temp);
  memory #(16,3,2) y(clk, d_out, data_out_temp, addr_y, wr_en_y);
  memory #(1,3,2) z(clk, overflow_temp, of, addr_z, wr_en_z);


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

module part2_mac(clk, clear_acc, a, b, d_out, valid_in, valid_out, overflow_temp);
        input clk, clear_acc, valid_in;
        input signed [7:0] a, b;
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
                        f <= 0;
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
// ESE-507 Project 2, Fall 2017

// This simple testbench is provided to help you in testing Project 2, Part 1.
// This testbench is not sufficient to test the full correctness of your system, it's just
// a relatively small test to help you get started.

// This testbench will test three matrix-vector multiplications. One of the outputs will
// overflow.

// The testbench will also check if your result is correct or not. If your design works
// correctly, you will see the following when you simulate:

/*
 # SUCCESS:          y[    0] =    186; overflow = 0
 # SUCCESS:          y[    1] =    152; overflow = 0
 # SUCCESS:          y[    2] =   -210; overflow = 0
 # SUCCESS:          y[    3] =   4191; overflow = 0
 # SUCCESS:          y[    4] = -17149; overflow = 1
 # SUCCESS:          y[    5] =    762; overflow = 0
 # SUCCESS:          y[    6] =   -494; overflow = 0
 # SUCCESS:          y[    7] =   1012; overflow = 0
 # SUCCESS:          y[    8] =    808; overflow = 0
 */

// If there is an error, you will see something like:
/*
 # SUCCESS:          y[    0] =    186; overflow = 0
 # SUCCESS:          y[    1] =    152; overflow = 0
 # SUCCESS:          y[    2] =   -210; overflow = 0
 # SUCCESS:          y[    3] =   4191; overflow = 0
 # ERROR:   Expected y[    4] = -17149; overflow = 1.   Instead your system produced: y[    4] = -17149; overflow = 0
 # SUCCESS:          y[    5] =    762; overflow = 0
 # SUCCESS:          y[    6] =   -494; overflow = 0
 # SUCCESS:          y[    7] =   1012; overflow = 0
 # SUCCESS:          y[    8] =    808; overflow = 0
 */

// Please let me know if you have any problems.

module check_timing();

   logic clk, s_valid, s_ready, m_valid, m_ready, reset, overflow;
   logic signed [7:0] data_in;
   logic signed [15:0] data_out;

   initial clk=0;
   always #5 clk = ~clk;


   mvm3_part1 dut (.clk(clk), .reset(reset), .s_valid(s_valid), .m_ready(m_ready),
		   .data_in(data_in), .m_valid(m_valid), .s_ready(s_ready), .data_out(data_out),
		   .overflow(overflow));


   //////////////////////////////////////////////////////////////////////////////////////////////////
   // code to feed some test inputs

   // rb and rb2 represent random bits. Each clock cycle, we will randomize the value of these bits.
   // When rb is 0, we will not let our testbench send new data to the DUT.
   // When rb is 1, we can send data.
   logic rb, rb2;
   always begin
      @(posedge clk);
      #1;
      void'(std::randomize(rb, rb2)); // randomize rb
   end

   // Put our test data into this array. These are the values we will feed as input into the system.
   logic [7:0] invals[0:35] = '{1, -8, 3, 9, -5, 11, -7, 8, -9, 1,  -22, 3,
				10, 11, 12, 127, 127, 127, 1,  2, 3, 127, 127, 127,
				19, 18, -17,  16,  -15,  14, 13, -12, 11, 19, -22, 27
				};



   logic signed [15:0] expVals[0:8]  = {186, 152, -210, 4191, -17149, 762, -494, 1012, 808};
   logic 	expOverflow[0:8] = {0, 0, 0, 0, 1, 0, 0, 0, 0};

   logic [15:0] j;

   // If s_valid is set to 1, we will put data on data_in.
   // If s_valid is 0, we will put an X on the data_in to test that your system does not
   // process the invalid input.
   always @* begin
      if (s_valid == 1)
         data_in = invals[j];
      else
         data_in = 'x;
   end

   // If our random bit rb is set to 1, and if j is within the range of our test vector (invals),
   // we will set s_valid to 1.
   always @* begin
      if ((j>=0) && (j<36) && (rb==1'b1)) begin
         s_valid=1;
      end
      else
         s_valid=0;
   end

   // If we set s_valid and s_ready on this clock edge, we will increment j just after
   // this clock edge.
   always @(posedge clk) begin
      if (s_valid && s_ready)
         j <= #1 j+1;
   end
   ////////////////////////////////////////////////////////////////////////////////////////
   // code to receive the output values

   // we will use another random bit (rb2) to determine if we can assert m_ready.
   logic [15:0] i;
   always @* begin
      if ((i>=0) && (i<36) && (rb2==1'b1) )
         m_ready = 1;
      else
         m_ready = 0;
   end

   always @(posedge clk) begin
      if (m_ready && m_valid) begin
	 if ((data_out == expVals[i]) && (overflow == expOverflow[i]))
           $display("SUCCESS:          y[%d] = %d; overflow = %b" , i, data_out, overflow);
	 else
	   $display("ERROR:   Expected y[%d] = %d; overflow = %b.   Instead your system produced: y[%d] = %d; overflow = %b" , i, expVals[i], expOverflow[i], i, data_out, overflow);
         i=i+1;
      end
   end

   ////////////////////////////////////////////////////////////////////////////////

   initial begin
      j=0; i=0;

      // Before first clock edge, initialize
      m_ready = 0;
      reset = 0;

      // reset
      @(posedge clk); #1; reset = 1;
      @(posedge clk); #1; reset = 0;

      // wait until 3 outputs have come out, then finish.
      wait(i==9);
      $finish;
   end


   // This is just here to keep the testbench from running forever in case of error.
   // In other words, if your system never produces three outputs, this code will stop
   // the simulation after 1000 clock cycles.
   initial begin
      repeat(1000) begin
         @(posedge clk);
      end
      $display("Warning: Output not produced within 1000 clock cycles; stopping simulation so it doens't run forever");
      $stop;
   end

endmodule
