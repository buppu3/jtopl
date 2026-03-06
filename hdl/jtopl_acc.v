/* This file is part of JTOPL.

 
    JTOPL program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTOPL program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTOPL.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 20-6-2020 

*/

module jtopl_acc(
    input                         rst,
    input                         clk,
    input                         cenop,
    input  signed [12:0]          op_result,
    input                         zero,
    input                         rhy2x,
    input         [3:0]           dac_en,
    input                         sum_en,
    output signed [OUTW-1:0]      snd_a,
    output signed [OUTW-1:0]      snd_b,
    output signed [OUTW-1:0]      snd_c,
    output signed [OUTW-1:0]      snd_d,
    output                        sample
);

parameter ACCW = 17;
parameter OUTW = 16;
parameter MONO = 0;
parameter OPL_TYPE=2;
parameter OP_WIDTH = 1;
parameter CON_WIDTH = 1;

assign sample = zero;

wire signed [13:0] op2x;
assign op2x   = rhy2x ? {op_result, 1'b0} : {op_result[12],op_result};

generate if(OPL_TYPE == 3 && MONO == 0) begin

wire sum_a_en = dac_en[0] & sum_en;
wire sum_b_en = dac_en[1] & sum_en;
wire sum_c_en = dac_en[2] & sum_en;
wire sum_d_en = dac_en[3] & sum_en;

// Continuous output
jtopl_single_acc #(.INW(14),.OUTW(OUTW), .ACCW(ACCW))  u_acc_a (
    .clk        ( clk       ),
    .cenop      ( cenop     ),
    .op_result  ( op2x      ),
    .sum_en     ( sum_a_en  ),
    .zero       ( zero      ),
    .snd        ( snd_a     )
);
jtopl_single_acc #(.INW(14),.OUTW(OUTW), .ACCW(ACCW))  u_acc_b (
    .clk        ( clk       ),
    .cenop      ( cenop     ),
    .op_result  ( op2x      ),
    .sum_en     ( sum_b_en  ),
    .zero       ( zero      ),
    .snd        ( snd_b     )
);
jtopl_single_acc #(.INW(14),.OUTW(OUTW), .ACCW(ACCW))  u_acc_c (
    .clk        ( clk       ),
    .cenop      ( cenop     ),
    .op_result  ( op2x      ),
    .sum_en     ( sum_c_en  ),
    .zero       ( zero      ),
    .snd        ( snd_c     )
);
jtopl_single_acc #(.INW(14),.OUTW(OUTW), .ACCW(ACCW))  u_acc_d (
    .clk        ( clk       ),
    .cenop      ( cenop     ),
    .op_result  ( op2x      ),
    .sum_en     ( sum_d_en  ),
    .zero       ( zero      ),
    .snd        ( snd_d     )
);

end else if(OPL_TYPE == 3 && MONO != 0) begin

wire sum_a_en = |dac_en & sum_en;

// Continuous output
jtopl_single_acc #(.INW(14),.OUTW(OUTW), .ACCW(ACCW))  u_acc(
    .clk        ( clk       ),
    .cenop      ( cenop     ),
    .op_result  ( op2x      ),
    .sum_en     ( sum_en    ),
    .zero       ( zero      ),
    .snd        ( snd_a     )
);

assign snd_b = 0;
assign snd_c = 0;
assign snd_d = 0;

end else begin

// Continuous output
jtopl_single_acc #(.INW(14),.OUTW(OUTW), .ACCW(ACCW))  u_acc(
    .clk        ( clk       ),
    .cenop      ( cenop     ),
    .op_result  ( op2x      ),
    .sum_en     ( sum_en    ),
    .zero       ( zero      ),
    .snd        ( snd_a     )
);

assign snd_b = snd_a;
assign snd_c = 0;
assign snd_d = 0;

end
endgenerate

endmodule
