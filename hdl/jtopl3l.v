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

module jtopl3l(
    input                  rst,        // rst should be at least 6 clk&cen cycles long
    input                  clk,        // CPU clock
    input                  cen,        // 33.8688MHz
    input           [ 7:0] din,
    input           [ 1:0] addr,
    input                  cs_n,
    input                  wr_n,
    output          [ 7:0] dout,
    output                 irq_n,
    // combined output
    output  signed  [OUTW-1:0] snd_l,
    output  signed  [OUTW-1:0] snd_r,
    output                 sample
);

parameter OPL_TYPE=3;
parameter SLOTS = 36;
parameter CHANNELS = 18;
parameter CH_WIDTH = 5;
parameter GROUP_WIDTH = 3;
parameter OP_WIDTH = 2;
parameter CON_WIDTH = 3;
parameter FB_WIDTH = 3;
parameter WAVESEL_WIDTH = 3;
parameter CLKDIV=19;
parameter MONO = 0;
parameter ACCW = 19;    // 13bit * 36op
parameter OUTW = 16;
parameter STATUS_BITS = 5'd6;
parameter OPL2_1_DAC_OUT = 4'b0011;
parameter OPL2_2_DAC_OUT = 4'b0011;

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
        .MONO(MONO),
        .ACCW(ACCW),
        .OUTW(OUTW),
        .STATUS_BITS(STATUS_BITS),
        .OPL2_1_DAC_OUT(OPL2_1_DAC_OUT),
        .OPL2_2_DAC_OUT(OPL2_2_DAC_OUT)
    ) u_base(
        .rst    ( rst       ),
        .clk    ( clk       ),
        .cen    ( cen       ),
        .din    ( din       ),
        .addr   ( addr      ),
        .cs_n   ( cs_n      ),
        .wr_n   ( wr_n      ),
        .dout   ( dout      ),
        .irq_n  ( irq_n     ),
        .snd_a  ( snd_l     ),
        .snd_b  ( snd_r     ),
        .snd_c  (           ),
        .snd_d  (           ),
        .sample ( sample    )
    );

endmodule