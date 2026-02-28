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

module jtopl_connection (
    input  [OP_WIDTH-1:0]  op,          // OP 番号
    input  [CON_WIDTH-1:0] con,         // アルゴリズム番号
    output                 car_en,      // OP をキャリアとして使用する
    output                 fb_in_en,    // FB バッファから入力する
    output                 fb_out_en,   // FB バッファへ出力する
    output                 sum_en       // ACC へ出力する
);

parameter OPL_TYPE=2;
parameter OP_WIDTH = 1;
parameter CON_WIDTH = 1;

generate if(OPL_TYPE == 3) begin

function is_carrier(
    input [CON_WIDTH-1:0] con,
    input [OP_WIDTH-1:0] op
);
    case ({con, op})
        // 2OP mode CNT=0
        5'b000_00:  is_carrier = 1'b0;
        5'b000_01:  is_carrier = 1'b1;

        // 2OP mode CNT=1
        5'b001_00:  is_carrier = 1'b0;
        5'b001_01:  is_carrier = 1'b0;

        // 4OP mode CNT(Cn)=0,CNT(Cn+3)=0
        5'b100_00:  is_carrier = 1'b0;
        5'b100_01:  is_carrier = 1'b1;
        5'b100_10:  is_carrier = 1'b1;
        5'b100_11:  is_carrier = 1'b1;

        // 4OP mode CNT(Cn)=0,CNT(Cn+3)=1
        5'b110_00:  is_carrier = 1'b0;
        5'b110_01:  is_carrier = 1'b1;
        5'b110_10:  is_carrier = 1'b0;
        5'b110_11:  is_carrier = 1'b1;

        // 4OP mode CNT(Cn)=1,CNT(Cn+3)=0
        5'b101_00:  is_carrier = 1'b0;
        5'b101_01:  is_carrier = 1'b0;
        5'b101_10:  is_carrier = 1'b1;
        5'b101_11:  is_carrier = 1'b1;

        // 4OP mode CNT(Cn)=1,CNT(Cn+3)=1
        5'b111_00:  is_carrier = 1'b0;
        5'b111_01:  is_carrier = 1'b0;
        5'b111_10:  is_carrier = 1'b1;
        5'b111_11:  is_carrier = 1'b0;

        default:    is_carrier = 1'b0;
    endcase
endfunction

assign car_en = is_carrier(con, op);

end else begin

assign car_en = op[0];

end
endgenerate

// fb in enable
assign fb_in_en = op == 1'd0;

// fb out enable
assign fb_out_en = op[0];

generate if(OPL_TYPE == 3) begin

function is_connect_acc(
    input [CON_WIDTH-1:0] con,
    input [OP_WIDTH-1:0] op
);
    case ({con, op})
        // 2OP CNT=0
        5'b000_00:  is_connect_acc = 1'b0;
        5'b000_01:  is_connect_acc = 1'b1;

        // 2OP CNT=1
        5'b001_00:  is_connect_acc = 1'b1;
        5'b001_01:  is_connect_acc = 1'b1;

        // 4OP mode CNT(Cn)=0,CNT(Cn+3)=0
        5'b100_00:  is_connect_acc = 1'b0;
        5'b100_01:  is_connect_acc = 1'b0;
        5'b100_10:  is_connect_acc = 1'b0;
        5'b100_11:  is_connect_acc = 1'b1;

        // 4OP mode CNT(Cn)=0,CNT(Cn+3)=1
        5'b110_00:  is_connect_acc = 1'b0;
        5'b110_01:  is_connect_acc = 1'b1;
        5'b110_10:  is_connect_acc = 1'b0;
        5'b110_11:  is_connect_acc = 1'b1;

        // 4OP mode CNT(Cn)=1,CNT(Cn+3)=0
        5'b101_00:  is_connect_acc = 1'b1;
        5'b101_01:  is_connect_acc = 1'b0;
        5'b101_10:  is_connect_acc = 1'b0;
        5'b101_11:  is_connect_acc = 1'b1;

        // 4OP mode CNT(Cn)=1,CNT(Cn+3)=1
        5'b111_00:  is_connect_acc = 1'b1;
        5'b111_01:  is_connect_acc = 1'b0;
        5'b111_10:  is_connect_acc = 1'b1;
        5'b111_11:  is_connect_acc = 1'b1;

        default:    is_connect_acc = 1'b0;
    endcase
endfunction

assign sum_en = is_connect_acc(con, op);

end else begin
assign sum_en = op[0] | con[0];
end
endgenerate

endmodule
