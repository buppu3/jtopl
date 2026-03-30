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
    Date: 13-6-2020
    
    */

module jtopl_pg(
    input                   rst,
    input                   clk,
    input                   cenop,
    input       [SLOTS-1:0] slot,
    // Channel frequency
    input       [ 9:0]      fnum_I,
    input       [ 2:0]      block_I,
    //
    input                   note_sel_I,
    // Operator multiplying
    input       [ 3:0]      mul_II,
    // phase modulation from LFO (vibrato at 6.4Hz)
    input       [ 2:0]      vib_cnt,
    input                   vib_dep,
    input                   viben_I,
    // phase operation
    input                   pg_rst_II,

    input                   rhy_en_I,
    input                   bd0_en_I,
    input                   hh_en_I,
    input                   sd_en_I,
    input                   tc_en_I,

    output  reg [ 3:0]      keycode_II,
    output      [ 9:0]      phase_IV
);

parameter OPL_TYPE=1;
parameter CHANNELS = 9;
parameter SLOTS=18;
parameter MODULE_COUNT = 1;
//parameter CH_WIDTH = 4;
//parameter GROUP_WIDTH = 2;
//parameter OP_WIDTH = 1;
//parameter CON_WIDTH = 1;
//parameter FB_WIDTH = 3;
//parameter WAVESEL_WIDTH = 2;
parameter CH=CHANNELS;

parameter   SLOT_RHY_BD0 = 12,
            SLOT_RHY_BD1 = 15,
            SLOT_RHY_SD  = 16,
            SLOT_RHY_TOM = 14,
            SLOT_RHY_TC  = 17,
            SLOT_RHY_HH  = 13;

wire [ 3:0] keycode_I;
wire [16:0] phinc_I;
reg  [16:0] phinc_II;
wire [18:0] phase_drop, phase_in;
wire [ 9:0] phase_II;
wire        noise;
reg  [MODULE_COUNT*10-1:0] hh, tc;
reg         rm_xor;

always @(posedge clk) if(cenop) begin
    keycode_II      <= keycode_I;
    phinc_II        <= phinc_I;
end

wire tc_bit = (tc[3]^tc[5]) | (hh[2]^hh[7]) | hh[3];

generate if(MODULE_COUNT <= 1) begin

// Rhythm phase
always @(posedge clk, posedge rst) begin
    if( rst ) begin
        hh <= 10'd0;
        tc <= 10'd0;
    end else if( cenop ) begin
        if( slot[(SLOT_RHY_HH+1)%SLOTS] ) hh <= phase_drop[18:9];
        if( slot[(SLOT_RHY_TC+1)%SLOTS] ) tc <= phase_drop[18:9];
        rm_xor <= tc_bit;
    end
end

end else begin

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        hh[$bits(hh)-1:10] <= 0;
    end else if( cenop ) begin
        if( bd0_en_I ) hh[$bits(hh)-1:10] <= hh[$bits(hh)-11:0];
    end
end

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        hh[9:0] <= 0;
    end else if( cenop ) begin
        if( hh_en_II )      hh[9:0] <= phase_drop[18:9];
        else if( bd0_en_I ) hh[9:0] <= hh[$bits(hh)-1:$bits(hh)-10];
    end
end

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        tc[$bits(tc)-1:10] <= 0;
    end else if( cenop ) begin
        if( bd0_en_I ) tc[$bits(tc)-1:10] <= tc[$bits(tc)-11:0];
    end
end

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        tc[9:0] <= 0;
    end else if( cenop ) begin
        if( tc_en_II )      tc[9:0] <= phase_drop[18:9];
        else if( bd0_en_I ) tc[9:0] <= tc[$bits(tc)-1:$bits(tc)-10];
    end
end

always @(*) begin
    rm_xor = tc_bit;
end

end
endgenerate

reg hh_en_II, sd_en_II, tc_en_II;
always @(posedge clk, posedge rst) begin
    if( rst ) begin
        hh_en_II <= 0;
        sd_en_II <= 0;
        tc_en_II <= 0;
    end else if( cenop ) begin
        hh_en_II <= rhy_en_I & hh_en_I;
        sd_en_II <= rhy_en_I & sd_en_I;
        tc_en_II <= rhy_en_I & tc_en_I;
    end
end

jtopl_noise u_noise(
    .clk    ( clk       ),
    .cen    ( cenop     ),
    .rst    ( rst       ),
    .noise  ( noise     )
);

jtopl_pg_comb u_comb(
    .block      ( block_I       ),
    .fnum       ( fnum_I        ),
    .note_sel   ( note_sel_I    ),
    // Phase Modulation
    .vib_cnt    ( vib_cnt       ),
    .vib_dep    ( vib_dep       ),
    .viben      ( viben_I       ),

    .keycode    ( keycode_I     ),
    // Phase increment  
    .phinc_out  ( phinc_I       ),
    // Phase add
    .mul        ( mul_II        ),
    .phase_in   ( phase_drop    ),
    .pg_rst     ( pg_rst_II     ),
    .phinc_in   ( phinc_II      ),
    // Rhythm
    .hh_en      ( hh_en_II      ),
    .sd_en      ( sd_en_II      ),
    .tc_en      ( tc_en_II      ),
    .rm_xor     ( rm_xor        ),
    .noise      ( noise         ),
    .hh         ( hh[9:0]       ),

    .phase_out  ( phase_in      ),
    .phase_op   ( phase_II      )
);

jtopl_sh_rst #( .width(19), .stages(2*CH) ) u_phsh(
    .clk    ( clk       ),
    .cen    ( cenop     ),
    .rst    ( rst       ),
    .din    ( phase_in  ),
    .drop   ( phase_drop)
);

jtopl_sh_rst #( .width(10), .stages(2) ) u_pad(
    .clk    ( clk       ),
    .cen    ( cenop     ),
    .rst    ( rst       ),  
    .din    ( phase_II  ),
    .drop   ( phase_IV  )
);

endmodule

