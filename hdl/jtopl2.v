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
    Date: 10-10-2021

    */

module jtopl2(
    input                  rst,        // rst should be at least 6 clk&cen cycles long
    input                  clk,        // CPU clock
    input                  cen,        // optional clock enable, it not needed leave as 1'b1
    input           [ 7:0] din,
    input                  addr,
    input                  cs_n,
    input                  wr_n,
    output          [ 7:0] dout,
    output                 irq_n,
    // combined output
    output  signed  [OUTW-1:0] snd,
    output                 sample
);

parameter OPL_TYPE=2;
parameter SLOTS = 18;
parameter CHANNELS = 9;
parameter CH_WIDTH = 4;
parameter GROUP_WIDTH = 2;
parameter OP_WIDTH = 1;
parameter CON_WIDTH = 1;
parameter FB_WIDTH = 3;
parameter WAVESEL_WIDTH = 2;
parameter ACCW = 18;    // 13bit * 18op
parameter OUTW = 16;
parameter CLKDIV=2;

    `define JTOPL2
    jtopl #(
        .OPL_TYPE(OPL_TYPE),
        .SLOTS(SLOTS),
        .CHANNELS(CHANNELS),
        .CH_WIDTH(CH_WIDTH),
        .GROUP_WIDTH(GROUP_WIDTH),
        .OP_WIDTH(OP_WIDTH),
        .CON_WIDTH(CON_WIDTH),
        .FB_WIDTH(FB_WIDTH),
        .WAVESEL_WIDTH(WAVESEL_WIDTH),
        .CLKDIV(CLKDIV),
        .ACCW(ACCW),
        .OUTW(OUTW)
    ) u_base(
        .rst    ( rst       ),
        .clk    ( clk       ),
        .cen    ( cen       ),
        .din    ( din       ),
        .addr   ({1'b0,addr}),
        .cs_n   ( cs_n      ),
        .wr_n   ( wr_n      ),
        .dout   ( dout      ),
        .irq_n  ( irq_n     ),
        .snd_a  ( snd       ),
        .snd_b  (           ),
        .snd_c  (           ),
        .snd_d  (           ),
        .sample ( sample    )
    );

endmodule