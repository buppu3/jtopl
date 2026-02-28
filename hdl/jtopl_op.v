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

    Based on Sauraen VHDL version of OPN/OPN2, which is based on die shots.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 19-6-2020

*/


module jtopl_op(
    input           rst,
    input           clk,
    input           cenop,

    // these signals need be delayed
    input   [GROUP_WIDTH-1:0]   group,
    input   [OP_WIDTH-1:0]      op, // 0 for modulator operators
    input   [CON_WIDTH-1:0]     con_I,
    input                       rhy_oen_I,
    input   [ 3:0]              dac_en_I,
    input   [FB_WIDTH-1:0]      fb_I,       // voice feedback

    input                       zero,

    input   [9:0]               pg_phase_I,
    input   [WAVESEL_WIDTH-1:0] wavsel_I,
    input   [9:0]               eg_atten_II, // output from envelope generator
    
    
    output reg signed [12:0]    op_result,
    output [ 3:0]               dac_en_out,
    output                      sum_en_out,
    output                      rhy2x_out
);

parameter OPL_TYPE=1;
parameter GROUP_WIDTH = 2;
parameter OP_WIDTH = 1;
parameter CON_WIDTH = 1;
parameter FB_WIDTH = 3;
parameter WAVESEL_WIDTH = 2;


localparam  OPW=13,     // Operator Width
            PW=OPW*2;   // Previous data Width

localparam  CTRLW = WAVESEL_WIDTH + GROUP_WIDTH + OP_WIDTH + CON_WIDTH + FB_WIDTH;

reg  [11:0] level_II;
reg         signbit_II, signbit_III;
reg         nullify_II;
reg         fast_II;
reg         sq_II;
reg         exp_II;

wire [CTRLW-1:0]         ctrl_in, ctrl_dly;
wire [GROUP_WIDTH-1:0]   group_d;
wire [OP_WIDTH-1:0]      op_d;
wire [CON_WIDTH-1:0]     con_I_d;
wire [WAVESEL_WIDTH-1:0] wavsel_d;
wire [FB_WIDTH-1:0]      fb_I_d;

reg  [PW-1:0] prev,  prev0_din, prev1_din, prev2_din;
wire [PW-1:0] prev0, prev1,     prev2;

reg  [PW-1:0] prev3_din, prev4_din, prev5_din;
wire [PW-1:0] prev3,     prev4,     prev5;

assign      ctrl_in = { wavsel_I, group, op, con_I, fb_I };
assign      { wavsel_d, group_d, op_d, con_I_d, fb_I_d } = ctrl_dly;

jtopl_sh #( .width(CTRLW), .stages(3)) u_delay(
    .clk    ( clk       ),
    .cen    ( cenop     ),
    .din    ( ctrl_in   ),
    .drop   ( ctrl_dly  )
);

wire car_en, fb_in_en, fb_out_en, sum_en;
jtopl_connection #(
    .OPL_TYPE(OPL_TYPE),
    .OP_WIDTH(OP_WIDTH),
    .CON_WIDTH(CON_WIDTH)
) u_con (
    .op        ( op_d      ),
    .con       ( con_I_d   ),
    .car_en    ( car_en    ),
    .fb_in_en  ( fb_in_en  ),
    .fb_out_en ( fb_out_en ),
    .sum_en    ( sum_en    )
);

jtopl_sh #( .width(1), .stages(3)) u_delay_sum_en (
    .clk    ( clk        ),
    .cen    ( cenop      ),
    .din    ( sum_en     ),
    .drop   ( sum_en_out )
);

jtopl_sh #( .width(4), .stages(3+3)) u_delay_dac_en (
    .clk    ( clk        ),
    .cen    ( cenop      ),
    .din    ( dac_en_I   ),
    .drop   ( dac_en_out )
);

wire [GROUP_WIDTH-1:0] group_out;
jtopl_sh #( .width(GROUP_WIDTH), .stages(3)) u_delay_group (
    .clk    ( clk        ),
    .cen    ( cenop      ),
    .din    ( group_d   ),
    .drop   ( group_out )
);

jtopl_sh #( .width(1), .stages(3+3)) u_delay_rhy2x (
    .clk    ( clk        ),
    .cen    ( cenop      ),
    .din    ( rhy_oen_I  ),
    .drop   ( rhy2x_out  )
);

always @(*) begin
    prev0_din     = fb_out_en && group_d==2'd0 ? { prev0[OPW-1:0], op_result } : prev0;
    prev1_din     = fb_out_en && group_d==2'd1 ? { prev1[OPW-1:0], op_result } : prev1;
    prev2_din     = fb_out_en && group_d==2'd2 ? { prev2[OPW-1:0], op_result } : prev2;
    if(GROUP_WIDTH>2) begin
        prev3_din     = fb_out_en && group_d==3'd3 ? { prev3[OPW-1:0], op_result } : prev3;
        prev4_din     = fb_out_en && group_d==3'd4 ? { prev4[OPW-1:0], op_result } : prev4;
        prev5_din     = fb_out_en && group_d==3'd5 ? { prev5[OPW-1:0], op_result } : prev5;
    end
    if(GROUP_WIDTH>2) begin
        case( group_d )
            default: prev = prev0;
            3'd1:    prev = prev1;
            3'd2:    prev = prev2;
            3'd3:    prev = prev3;
            3'd4:    prev = prev4;
            3'd5:    prev = prev5;
        endcase
    end else begin
        case( group_d )
            default: prev = prev0;
            2'd1:    prev = prev1;
            2'd2:    prev = prev2;
        endcase
    end
end

jtopl_sh #( .width(PW), .stages(3)) u_csr0(
    .clk    ( clk       ),
    .cen    ( cenop     ),
    .din    ( prev0_din ),
    .drop   ( prev0     )
);

jtopl_sh #( .width(PW), .stages(3)) u_csr1(
    .clk    ( clk       ),
    .cen    ( cenop     ),
    .din    ( prev1_din ),
    .drop   ( prev1     )
);

jtopl_sh #( .width(PW), .stages(3)) u_csr2(
    .clk    ( clk       ),
    .cen    ( cenop     ),
    .din    ( prev2_din ),
    .drop   ( prev2     )
);

generate if(GROUP_WIDTH>2) begin
jtopl_sh #( .width(PW), .stages(3)) u_csr3(
    .clk    ( clk       ),
    .cen    ( cenop     ),
    .din    ( prev3_din ),
    .drop   ( prev3     )
);

jtopl_sh #( .width(PW), .stages(3)) u_csr4(
    .clk    ( clk       ),
    .cen    ( cenop     ),
    .din    ( prev4_din ),
    .drop   ( prev4     )
);

jtopl_sh #( .width(PW), .stages(3)) u_csr5(
    .clk    ( clk       ),
    .cen    ( cenop     ),
    .din    ( prev5_din ),
    .drop   ( prev5     )
);
end
endgenerate

reg [   10:0]  subtresult;
reg [OPW-1:0]  shifter;
wire signed [OPW-1:0] fb1 = prev[PW-1:OPW];
wire signed [OPW-1:0] fb0 = prev[OPW-1:0];

// REGISTER/CYCLE 1
// Creation of phase modulation (FM) feedback signal, before shifting
reg signed [OPW-1:0] modmux_I;
reg signed [OPW-1:0] fbmod_I;

always @(*) begin
    modmux_I = fb_in_en ? (fb1+fb0) : op_result;    // op_result には 3slot 前の演算結果が格納されている
    // OPL-L shifts by 8-FB
    // OPL3  shifts by 9-FB
    // OPLL seems to use lower resolution for OPW so it makes
    // sense that it shifts by one fewer
    fbmod_I  = modmux_I>>>(4'd9-{1'b0,fb_I_d});
end

reg signed [9:0] phasemod_I;

always @(*) begin
    // Shift FM feedback signal
    if (fb_in_en)
        phasemod_I = fb_I_d==3'd0 ? 10'd0 : fbmod_I[9:0];
    else if(car_en)
        phasemod_I = modmux_I[9:0];
    else
        phasemod_I = 10'd0;
end

reg [ 9:0]  phase;
reg [ 7:0]  aux_I;
reg [11:0]  aux_exp_I;

always @(*) begin
    phase      = phasemod_I + pg_phase_I;
    aux_I      = phase[7:0] ^ {8{~phase[8]}};
    aux_exp_I  = {phase[7:0] ^ {8{phase[9]}}, 4'b0000};
end

// REGISTER/CYCLE 1

always @(posedge clk) if( cenop ) begin    
    if( OPL_TYPE==1 ) begin
        signbit_II <= phase[9];
        nullify_II <= 0;
        fast_II    <= 0;
        sq_II      <= 0;
        exp_II     <= 0;
    end else if( OPL_TYPE == 2) begin
        signbit_II <= (wavsel_d==0 && phase[9]);
        nullify_II <= (wavsel_d==2'b01 && phase[9]) || (wavsel_d==2'b11 && phase[8]);
        fast_II    <= 0;
        sq_II      <= 0;
        exp_II     <= 0;
    end else begin
        signbit_II <= (wavsel_d==3'd0 && phase[9]) || (wavsel_d==3'd4 && phase[8]) || (wavsel_d==3'd6 && phase[9]) || (wavsel_d==3'd7 && phase[9]);
        nullify_II <= (wavsel_d==3'd1 && phase[9]) || (wavsel_d==3'd3 && phase[8]) || (wavsel_d==3'd4 && phase[9]) || (wavsel_d==3'd5 && phase[9]);
        fast_II    <= (wavsel_d == 3'd4) || (wavsel_d == 3'd5);
        sq_II      <= (wavsel_d == 3'd6);
        exp_II     <= (wavsel_d == 3'd7);
    end
end

reg  [11:0]  logexp_II;
always @(posedge clk) if( cenop ) begin    
    if(OPL_TYPE == 3) logexp_II <= aux_exp_I;
end

wire [11:0]  logsinnorm_II;
wire [11:0]  logsinfast_II;
jtopl_logsin u_logsin (
    .clk     ( clk           ),
    .cen     ( cenop         ),
    .addr    ( aux_I[7:0]    ),
    .logsin  ( logsinnorm_II ),
    .logsin2 ( logsinfast_II )
);

// REGISTER/CYCLE 2
// Sine table    
// Main sine table body

wire [11:0]  logsig_II = nullify_II ? ~12'h000 :
                         exp_II     ? logexp_II :
                         sq_II      ? 12'h000 :
                         fast_II    ? logsinfast_II : logsinnorm_II;
always @(*) begin
    subtresult = eg_atten_II + logsig_II[11:2];
    level_II   = { subtresult[9:0], logsig_II[1:0] } | {12{subtresult[10]}};
    //if( nullify_II ) begin
    //    level_II = ~12'h0;
    //end
end

wire [9:0] mantissa_III;
reg  [3:0] exponent_III;

jtopl_exprom u_exprom(
    .clk    ( clk           ),
    .cen    ( cenop         ),
    .addr   ( level_II[7:0] ),
    .exp    ( mantissa_III  )
);

always @(posedge clk) if( cenop ) begin
    exponent_III <= level_II[11:8];    
    signbit_III  <= signbit_II;    
end

// REGISTER/CYCLE 3
// 2's complement & Carry-out discarded

always @(*) begin    
    // Floating-point to integer, and incorporating sign bit
    shifter = { 2'b01, mantissa_III,1'b0 } >> exponent_III;
end

// It looks like OPLL and OPL3 don't do full 2's complement but just bit inversion
always @(posedge clk) if( cenop ) begin
    op_result <= ( shifter ^ {OPW{signbit_III}});// + {13'd0,signbit_III};
end

`ifdef SIMULATION
reg signed [OPW-1:0] op_sep0_0;
reg signed [OPW-1:0] op_sep1_0;
reg signed [OPW-1:0] op_sep2_0;
reg signed [OPW-1:0] op_sep0_1;
reg signed [OPW-1:0] op_sep1_1;
reg signed [OPW-1:0] op_sep2_1;
reg signed [OPW-1:0] op_sep4_0;
reg signed [OPW-1:0] op_sep5_0;
reg signed [OPW-1:0] op_sep6_0;
reg signed [OPW-1:0] op_sep4_1;
reg signed [OPW-1:0] op_sep5_1;
reg signed [OPW-1:0] op_sep6_1;
reg signed [OPW-1:0] op_sep7_0;
reg signed [OPW-1:0] op_sep8_0;
reg signed [OPW-1:0] op_sep9_0;
reg signed [OPW-1:0] op_sep7_1;
reg signed [OPW-1:0] op_sep8_1;
reg signed [OPW-1:0] op_sep9_1;
reg        [ 4:0] sepcnt;

always @(posedge clk) if(cenop) begin
    sepcnt <= zero ? 5'd0 : sepcnt+5'd1;
    case( (sepcnt+3)%18  )
        0: op_sep0_0 <= op_result;
        1: op_sep1_0 <= op_result;
        2: op_sep2_0 <= op_result;
        3: op_sep0_1 <= op_result;
        4: op_sep1_1 <= op_result;
        5: op_sep2_1 <= op_result;
        6: op_sep4_0 <= op_result;
        7: op_sep5_0 <= op_result;
        8: op_sep6_0 <= op_result;
        9: op_sep4_1 <= op_result;
       10: op_sep5_1 <= op_result;
       11: op_sep6_1 <= op_result;
       12: op_sep7_0 <= op_result;
       13: op_sep8_0 <= op_result;
       14: op_sep9_0 <= op_result;
       15: op_sep7_1 <= op_result;
       16: op_sep8_1 <= op_result;
       17: op_sep9_1 <= op_result;
    endcase
end

`endif

endmodule
