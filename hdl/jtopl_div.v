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
    Date: 10-6-2020

    */

module jtopl_div(
    input       rst,
    input       clk,
    input       cen,
    output reg  cenop   // clock enable at operator rate
);

parameter OPL_TYPE=1;
parameter CLKDIV=1<<2;

localparam W = $clog2(CLKDIV);

reg  [W-1:0] cnt;

`ifdef SIMULATION
initial cnt={W{1'b0}};
`endif

generate
    if((1<<W) == CLKDIV) begin
        always @(posedge clk) if(cen) begin
            cnt <= cnt+1'd1;
        end
    end
    else begin
        always @(posedge clk) if(cen) begin
            if(cnt == (CLKDIV-1)) begin
                cnt <= 0;
            end
            else begin
                cnt <= cnt+1'd1;
            end
        end
    end
endgenerate

always @(posedge clk) begin
    cenop <= cen && (&cnt);
end

endmodule
