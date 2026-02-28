/* This file is part of JTOPL

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
    Date: 13-6-2020 

*/

module jtopl_slot_cnt(
    input                        rst,
    input                        clk,
    input                        cen,
    input      [5:0]             consel,
    input                        new_en,

    // Pipeline order
    output                       zero,
    output reg [GROUP_WIDTH-1:0] group,
    output reg [OP_WIDTH-1:0]    op,           // 0 for modulator operators    
    output reg [ 2:0]            subslot,
    output reg [SLOTS-1:0]       slot         // hot one encoding of active slot
);

parameter OPL_TYPE=1;
parameter SLOTS = 18;
//parameter CHANNELS = 9;
//parameter CH_WIDTH = 4;
parameter GROUP_WIDTH = 2;
parameter OP_WIDTH = 1;
//parameter CON_WIDTH = 1;
//parameter FB_WIDTH = 3;
//parameter WAVESEL_WIDTH = 2;

parameter GROUPS = (SLOTS / 6);

// Each group contains three channels
// and each subslot contains six operators
wire [2:0]             next_sub   = subslot==3'd5 ? 3'd0 : (subslot+3'd1);
wire [GROUP_WIDTH-1:0] next_group = subslot==3'd5 ? (group==(GROUPS-1) ? 2'b00 : group+2'b1) : group;

`ifdef SIMULATION
// These signals need to operate during rst
// initial state is not relevant (or critical) in real life
// but we need a clear value during simulation
initial begin
    group   = 2'd0;
    subslot = 3'd0;
    slot    = 18'd1;
end
`endif

assign     zero = slot[0];

always @(posedge clk) begin : up_counter
    if( cen ) begin
        { group, subslot }  <= { next_group, next_sub };
        if( { next_group, next_sub }==5'd0 ) begin
            slot <= 18'd1;
        end else begin
            slot <= { slot[SLOTS-2:0], 1'b0 };
        end
        if( OPL_TYPE == 3) begin
            case({next_group, next_sub})
                6'b000_000: op <= 2'd0;
                6'b000_001: op <= 2'd0;
                6'b000_010: op <= 2'd0;
                6'b000_011: op <= 2'd1;
                6'b000_100: op <= 2'd1;
                6'b000_101: op <= 2'd1;

                6'b001_000: op <= {new_en & consel[0], 1'b0};
                6'b001_001: op <= {new_en & consel[1], 1'b0};
                6'b001_010: op <= {new_en & consel[2], 1'b0};
                6'b001_011: op <= {new_en & consel[0], 1'b1};
                6'b001_100: op <= {new_en & consel[1], 1'b1};
                6'b001_101: op <= {new_en & consel[2], 1'b1};

                6'b010_000: op <= 2'd0;
                6'b010_001: op <= 2'd0;
                6'b010_010: op <= 2'd0;
                6'b010_011: op <= 2'd1;
                6'b010_100: op <= 2'd1;
                6'b010_101: op <= 2'd1;

                6'b011_000: op <= 2'd0;
                6'b011_001: op <= 2'd0;
                6'b011_010: op <= 2'd0;
                6'b011_011: op <= 2'd1;
                6'b011_100: op <= 2'd1;
                6'b011_101: op <= 2'd1;

                6'b100_000: op <= {new_en & consel[3], 1'b0};
                6'b100_001: op <= {new_en & consel[4], 1'b0};
                6'b100_010: op <= {new_en & consel[5], 1'b0};
                6'b100_011: op <= {new_en & consel[3], 1'b1};
                6'b100_100: op <= {new_en & consel[4], 1'b1};
                6'b100_101: op <= {new_en & consel[5], 1'b1};

                6'b101_000: op <= 2'd0;
                6'b101_001: op <= 2'd0;
                6'b101_010: op <= 2'd0;
                6'b101_011: op <= 2'd1;
                6'b101_100: op <= 2'd1;
                6'b101_101: op <= 2'd1;

                default:    op <= 2'd0;
            endcase
        end
        else begin
            op <= next_sub >= 3'd3;
        end
    end
end

endmodule