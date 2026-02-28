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

module jtopl_eg_pure(
    input           attack,
    input           step,
    input [ 5:1]    rate,
    input [ 9:0]    eg_in,
    input           sum_up,
    output reg  [9:0] eg_pure
);

reg [ 3:0]  dr_sum;
reg [10:0]  dr_result;

always @(*) begin : dr_calculation
    case (rate[5:2])
        4'd 0:  dr_sum = 0;
        4'd13:  dr_sum = step ? 2<<1 : 1<<1;
        4'd14:  dr_sum = step ? 4<<1 : 2<<1;
        4'd15:  dr_sum = 4 << 1;
        default:dr_sum = {2'b0, step, 1'b0 };
    endcase

    dr_result = eg_in + {6'd0, dr_sum};
end

reg signed [10:0] ar_inv;
reg signed [10:0] ar_result;
reg signed [10:0] ar_sum;

always @(*) begin : ar_calculation
    ar_inv = ~{1'b0,eg_in};
    case (rate[5:2])
        4'd 0:  ar_sum = 0;
        4'd13:  ar_sum = step ? {3'b0, eg_in[9:2]} : {4'b0, eg_in[9:3]};    // eg_in * (step ? 2/8 : 1/8)
        4'd14:  ar_sum = step ? {2'b0, eg_in[9:1]} : {3'b0, eg_in[9:2]};    // eg_in * (step ? 4/8 : 2/8)
        4'd15:  ar_sum =        {1'b0, eg_in[9:0]};                         // eg_in * 8/8
        default:ar_sum = step ? {4'b0, eg_in[9:3]} : -1;                    // eg_in * (step ? 1/8 : 0/8)
    endcase

    ar_result = eg_in + ~ar_sum;
end

///////////////////////////////////////////////////////////
// rate not used below this point
reg [9:0] eg_pre_fastar; // pre fast attack rate
always @(*) begin
    if(sum_up) begin
        if( attack  )
            eg_pre_fastar = ar_result[10] ? 10'd0: ar_result[9:0];
        else 
            eg_pre_fastar = dr_result[10] ? 10'h3FF : dr_result[9:0];
    end
    else eg_pre_fastar = eg_in;
    eg_pure = (attack&rate[5:2]==4'd15) ? 10'd0 : eg_pre_fastar;
end



endmodule