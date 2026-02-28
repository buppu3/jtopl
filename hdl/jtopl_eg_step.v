/*  This file is part of JTOPL.

    JTOPL is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTOPL is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTOPL.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 17-6-2020

    */

module jtopl_eg_step(
    input             attack,
    input      [ 4:0] base_rate,
    input      [ 3:0] keycode,
    input      [14:0] eg_cnt,
    input             cnt_in,
    input             ksr,
    output            cnt_lsb,
    output reg        step,
    output reg [ 5:0] rate,
    output reg        sum_up
);

reg  [6:0]   pre_rate;
wire [3:0]   rof;

assign rof = ksr ? keycode[3:0] : {2'd0, keycode[3:2]};

always @(*) begin : pre_rate_calc
    if( base_rate[4:1] == 0 )
        pre_rate = 7'd0;
    else
        pre_rate = {1'd0, base_rate[4:1], 2'd0} + {3'd0, rof};
end

always @(*)
    rate = pre_rate[6] ? 6'b1111_11 : pre_rate[5:0];

reg [2:0] cnt;

//reg [3:0] mux_sel;
//always @(*) begin
//    mux_sel = rate[5:2];
//end

always @(*) 
    case( rate[5:2] )
        5'h0:    cnt = eg_cnt[14:12];
        5'h1:    cnt = eg_cnt[13:11];
        5'h2:    cnt = eg_cnt[12:10];
        5'h3:    cnt = eg_cnt[11: 9];
        5'h4:    cnt = eg_cnt[10: 8];
        5'h5:    cnt = eg_cnt[ 9: 7];
        5'h6:    cnt = eg_cnt[ 8: 6];
        5'h7:    cnt = eg_cnt[ 7: 5];
        5'h8:    cnt = eg_cnt[ 6: 4];
        5'h9:    cnt = eg_cnt[ 5: 3];
        5'ha:    cnt = eg_cnt[ 4: 2];
        5'hb:    cnt = eg_cnt[ 3: 1];
        default: cnt = eg_cnt[ 2: 0];
    endcase

////////////////////////////////
reg [7:0] step_idx;

always @(*) begin : rate_step
    if(rate[5:2] >= 4'd13) begin
        case( rate[1:0] )
            2'd0: step_idx = 8'b00000000;
            2'd1: step_idx = 8'b00010001;
            2'd2: step_idx = 8'b01010101;
            2'd3: step_idx = 8'b01110111;
        endcase
    end
    else begin
        case( rate[1:0] )
            2'd0: step_idx = 8'b01010101;
            2'd1: step_idx = 8'b01011101;
            2'd2: step_idx = 8'b01110111;
            2'd3: step_idx = 8'b01111111;
        endcase
    end

    step = step_idx[ cnt ];
end

assign cnt_lsb = cnt[0];
always @(*) begin
    sum_up = cnt[0] != cnt_in;
end

endmodule // eg_step