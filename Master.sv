module master(data_in, ready, data_out, valid_in, valid, clk, rst)

       input data_in,ready,valid,rst;
       intput clk;
       output data_out,valid_in;

      reg state,next;

      parameters  S0 = 1b'0;
                  S1 = 1b'1;

      always @(posedge clk) begin
             if(rst == 1)
                 state <= S0 ;
             else
                 state <= next ;
          end

      always @(data_in or state or valid) begin
          valid_in = 0;
          case (state)
             S0 : if(valid == 0)
                     next = S0;
                  else next = S1;

             S1 : if (valid == 1 && ready == 1)
                     data_out = data_in;
                  end
          endcase
      end
  endmodule


module slave(dataS_in, ready , data_out, valid_in, clk, rst, ready_in)

       input valid_in, data_out, rst, ready_in;
       input clk ;
       output ready, dataS_in;

       reg state,next;

       parameter   S0 = 1b'0;
                   S1 = 1b'1;

                   always @(posedge clk) begin
                          if(rst == 1)
                              state <= S0 ;
                          else
                              state <= next ;
                       end

         always @(data_in or state or valid) begin
                  valid_in = 0;
                  case (state)
                       S0 : if(ready == 0)
                               next = S0;
                            else next = S1;

                        S1 : if (valid == 1 && ready == 1)
                                      data_out = data_in;

                  endcase
          end
  endmodule
