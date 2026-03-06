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
    Date: 28-5-2022

*/

module jtopl_reg_ch(
    input             rst,
    input             clk,
    input             cen,
    input             zero,
    input                         rhy_en[MODULE_COUNT-1:0],
    input       [4:0]             rhy_kon[MODULE_COUNT-1:0],
    input       [SLOTS-1:0]       slot,

    input       [CH_WIDTH-1:0]    up_ch,
    input                         up_fnumhi,
    input                         up_fnumlo,
    input                         up_fbcon,
    input       [7:0]             din,

    input       [GROUP_WIDTH-1:0] group,
    input       [2:0]             sub,
    input       [5:0]             consel,
    input                         new_en,

    output reg                    keyon,
    output reg  [2:0]             block,
    output reg  [9:0]             fnum,
    output reg  [FB_WIDTH-1:0]    fb,
    output reg  [CON_WIDTH-1:0]   con,
    output reg  [3:0]             dac_en,
    output reg                    rhy_oen,    // high for rhythm operators if rhy_en is set
    output reg                    bd0_en,
    output reg                    hh_en,
    output reg                    sd_en,
    output reg                    tc_en,
    output                        rhyon_csr,
    input                         am_dep[MODULE_COUNT-1:0],
    input                         vib_dep[MODULE_COUNT-1:0],
    output reg                    am_dep_I,
    output reg                    vib_dep_I
);

parameter OPL_TYPE=1;
parameter MODULE_COUNT = 1;
parameter SLOTS = 18;
parameter CHANNELS = 9;
parameter CH_WIDTH = 4;
parameter GROUP_WIDTH = 2;
//parameter OP_WIDTH = 1;
parameter CON_WIDTH = 1;
parameter FB_WIDTH = 3;
//parameter WAVESEL_WIDTH = 2;
parameter SLOT_RHY_START = 12;
parameter SLOT_RHY_END = 17;
parameter OPL2_1_DAC_OUT = 4'b0011;
parameter OPL2_2_DAC_OUT = 4'b0011;

parameter   SLOT_RHY_BD0 = 12,
            SLOT_RHY_BD1 = 15,
            SLOT_RHY_SD  = 16,
            SLOT_RHY_TOM = 14,
            SLOT_RHY_TC  = 17,
            SLOT_RHY_HH  = 13;

// Rhythm key-on CSR
localparam BD=4, SD=3, TOM=2, TC=1, HH=0;

reg  [5:0] rhy_csr;

reg  [CHANNELS-1:0]  reg_keyon, reg_con;
reg  [2:0]           reg_block [CHANNELS-1:0];
reg  [FB_WIDTH-1:0]  reg_fb    [CHANNELS-1:0];
reg  [9:0]           reg_fnum  [CHANNELS-1:0];
reg  [3:0]           reg_dac_en[CHANNELS-1:0];
reg  [CH_WIDTH-1:0]  cur, i;

assign rhyon_csr = rhy_csr[5];

generate if(CHANNELS > 9) begin
always @* casez( {group,sub} )
    6'o55 : cur = 0;
    6'o00 : cur = 1;
    6'o01 : cur = 2;
    6'o02 : cur = 0;
    6'o03 : cur = 1;
    6'o04 : cur = 2;

    6'o05 : cur = 3;
    6'o10 : cur = 4;
    6'o11 : cur = 5;
    6'o12 : cur = 3;
    6'o13 : cur = 4;
    6'o14 : cur = 5;

    6'o15 : cur = 6;
    6'o20 : cur = 7;
    6'o21 : cur = 8;
    6'o22 : cur = 6;
    6'o23 : cur = 7;
    6'o24 : cur = 8;

    6'o25 : cur =  9;
    6'o30 : cur = 10;
    6'o31 : cur = 11;
    6'o32 : cur =  9;
    6'o33 : cur = 10;
    6'o34 : cur = 11;

    6'o35 : cur = 12;
    6'o40 : cur = 13;
    6'o41 : cur = 14;
    6'o42 : cur = 12;
    6'o43 : cur = 13;
    6'o44 : cur = 14;

    6'o45 : cur = 15;
    6'o50 : cur = 16;
    6'o51 : cur = 17;
    6'o52 : cur = 15;
    6'o53 : cur = 16;
    6'o54 : cur = 17;

    default: cur = 4'hx;
endcase

end else begin
always @* casez( {group,sub} )
    5'o00 : cur = 1;
    5'o01 : cur = 2;
    5'o02 : cur = 0;
    5'o03 : cur = 1;
    5'o04 : cur = 2;
    5'o05 : cur = 3;
    5'o10 : cur = 4;
    5'o11 : cur = 5;
    5'o12 : cur = 3;
    5'o13 : cur = 4;
    5'o14 : cur = 5;
    5'o15 : cur = 6;
    5'o20 : cur = 7;
    5'o21 : cur = 8;
    5'o22 : cur = 6;
    5'o23 : cur = 7;
    5'o24 : cur = 8;
    5'o25 : cur = 0;
    default: cur = 4'hx;
endcase
end
endgenerate

generate if(OPL_TYPE == 3) begin
    always @(posedge clk, posedge rst) begin
        if( rst ) begin
            con   <= 0;
        end else if(cen) begin
            case ({group, sub})
                6'o55:  con <= (new_en & consel[0]) ? { 1'b1, reg_con[ 3], reg_con[ 0]} : { 1'b0, 1'b0, reg_con[ 0]};
                6'o00:  con <= (new_en & consel[1]) ? { 1'b1, reg_con[ 4], reg_con[ 1]} : { 1'b0, 1'b0, reg_con[ 1]};
                6'o01:  con <= (new_en & consel[2]) ? { 1'b1, reg_con[ 5], reg_con[ 2]} : { 1'b0, 1'b0, reg_con[ 2]};
                6'o02:  con <= (new_en & consel[0]) ? { 1'b1, reg_con[ 3], reg_con[ 0]} : { 1'b0, 1'b0, reg_con[ 0]};
                6'o03:  con <= (new_en & consel[1]) ? { 1'b1, reg_con[ 4], reg_con[ 1]} : { 1'b0, 1'b0, reg_con[ 1]};
                6'o04:  con <= (new_en & consel[2]) ? { 1'b1, reg_con[ 5], reg_con[ 2]} : { 1'b0, 1'b0, reg_con[ 2]};

                6'o05:  con <= (new_en & consel[0]) ? { 1'b1, reg_con[ 3], reg_con[ 0]} : { 1'b0, 1'b0, reg_con[ 3]};
                6'o10:  con <= (new_en & consel[1]) ? { 1'b1, reg_con[ 4], reg_con[ 1]} : { 1'b0, 1'b0, reg_con[ 4]};
                6'o11:  con <= (new_en & consel[2]) ? { 1'b1, reg_con[ 5], reg_con[ 2]} : { 1'b0, 1'b0, reg_con[ 5]};
                6'o12:  con <= (new_en & consel[0]) ? { 1'b1, reg_con[ 3], reg_con[ 0]} : { 1'b0, 1'b0, reg_con[ 3]};
                6'o13:  con <= (new_en & consel[1]) ? { 1'b1, reg_con[ 4], reg_con[ 1]} : { 1'b0, 1'b0, reg_con[ 4]};
                6'o14:  con <= (new_en & consel[2]) ? { 1'b1, reg_con[ 5], reg_con[ 2]} : { 1'b0, 1'b0, reg_con[ 5]};

                6'o15:  con <= { 1'b0, 1'b0, reg_con[ 6]};
                6'o20:  con <= { 1'b0, 1'b0, reg_con[ 7]};
                6'o21:  con <= { 1'b0, 1'b0, reg_con[ 8]};
                6'o22:  con <= { 1'b0, 1'b0, reg_con[ 6]};
                6'o23:  con <= { 1'b0, 1'b0, reg_con[ 7]};
                6'o24:  con <= { 1'b0, 1'b0, reg_con[ 8]};

                6'o25:  con <= (new_en & consel[3]) ? { 1'b1, reg_con[12], reg_con[ 9]} : { 1'b0, 1'b0, reg_con[ 9]};
                6'o30:  con <= (new_en & consel[4]) ? { 1'b1, reg_con[13], reg_con[10]} : { 1'b0, 1'b0, reg_con[10]};
                6'o31:  con <= (new_en & consel[5]) ? { 1'b1, reg_con[14], reg_con[11]} : { 1'b0, 1'b0, reg_con[11]};
                6'o32:  con <= (new_en & consel[3]) ? { 1'b1, reg_con[12], reg_con[ 9]} : { 1'b0, 1'b0, reg_con[ 9]};
                6'o33:  con <= (new_en & consel[4]) ? { 1'b1, reg_con[13], reg_con[10]} : { 1'b0, 1'b0, reg_con[10]};
                6'o34:  con <= (new_en & consel[5]) ? { 1'b1, reg_con[14], reg_con[11]} : { 1'b0, 1'b0, reg_con[11]};

                6'o35:  con <= (new_en & consel[3]) ? { 1'b1, reg_con[12], reg_con[ 9]} : { 1'b0, 1'b0, reg_con[12]};
                6'o40:  con <= (new_en & consel[4]) ? { 1'b1, reg_con[13], reg_con[10]} : { 1'b0, 1'b0, reg_con[13]};
                6'o41:  con <= (new_en & consel[5]) ? { 1'b1, reg_con[14], reg_con[11]} : { 1'b0, 1'b0, reg_con[14]};
                6'o42:  con <= (new_en & consel[3]) ? { 1'b1, reg_con[12], reg_con[ 9]} : { 1'b0, 1'b0, reg_con[12]};
                6'o43:  con <= (new_en & consel[4]) ? { 1'b1, reg_con[13], reg_con[10]} : { 1'b0, 1'b0, reg_con[13]};
                6'o44:  con <= (new_en & consel[5]) ? { 1'b1, reg_con[14], reg_con[11]} : { 1'b0, 1'b0, reg_con[14]};

                6'o45:  con <= { 1'b0, 1'b0, reg_con[15]};
                6'o50:  con <= { 1'b0, 1'b0, reg_con[16]};
                6'o51:  con <= { 1'b0, 1'b0, reg_con[17]};
                6'o52:  con <= { 1'b0, 1'b0, reg_con[15]};
                6'o53:  con <= { 1'b0, 1'b0, reg_con[16]};
                6'o54:  con <= { 1'b0, 1'b0, reg_con[17]};

                default:con <= 0;
            endcase
        end
    end

    always @(posedge clk, posedge rst) begin
        if( rst ) begin
            keyon <= 0;
        end else if(cen) begin
            case ({group, sub})
                6'o55:  keyon <=                                        reg_keyon[ 0];
                6'o00:  keyon <=                                        reg_keyon[ 1];
                6'o01:  keyon <=                                        reg_keyon[ 2];
                6'o02:  keyon <=                                        reg_keyon[ 0];
                6'o03:  keyon <=                                        reg_keyon[ 1];
                6'o04:  keyon <=                                        reg_keyon[ 2];

                6'o05:  keyon <= (new_en & consel[0]) ? reg_keyon[ 0] : reg_keyon[ 3];
                6'o10:  keyon <= (new_en & consel[1]) ? reg_keyon[ 1] : reg_keyon[ 4];
                6'o11:  keyon <= (new_en & consel[2]) ? reg_keyon[ 2] : reg_keyon[ 5];
                6'o12:  keyon <= (new_en & consel[0]) ? reg_keyon[ 0] : reg_keyon[ 3];
                6'o13:  keyon <= (new_en & consel[1]) ? reg_keyon[ 1] : reg_keyon[ 4];
                6'o14:  keyon <= (new_en & consel[2]) ? reg_keyon[ 2] : reg_keyon[ 5];

                6'o15:  keyon <=                                        reg_keyon[ 6];
                6'o20:  keyon <=                                        reg_keyon[ 7];
                6'o21:  keyon <=                                        reg_keyon[ 8];
                6'o22:  keyon <=                                        reg_keyon[ 6];
                6'o23:  keyon <=                                        reg_keyon[ 7];
                6'o24:  keyon <=                                        reg_keyon[ 8];

                6'o25:  keyon <=                                        reg_keyon[ 9];
                6'o30:  keyon <=                                        reg_keyon[10];
                6'o31:  keyon <=                                        reg_keyon[11];
                6'o32:  keyon <=                                        reg_keyon[ 9];
                6'o33:  keyon <=                                        reg_keyon[10];
                6'o34:  keyon <=                                        reg_keyon[11];

                6'o35:  keyon <= (new_en & consel[3]) ? reg_keyon[ 9] : reg_keyon[12];
                6'o40:  keyon <= (new_en & consel[4]) ? reg_keyon[10] : reg_keyon[13];
                6'o41:  keyon <= (new_en & consel[5]) ? reg_keyon[11] : reg_keyon[14];
                6'o42:  keyon <= (new_en & consel[3]) ? reg_keyon[ 9] : reg_keyon[12];
                6'o43:  keyon <= (new_en & consel[4]) ? reg_keyon[10] : reg_keyon[13];
                6'o44:  keyon <= (new_en & consel[5]) ? reg_keyon[11] : reg_keyon[14];

                6'o45:  keyon <=                                        reg_keyon[15];
                6'o50:  keyon <=                                        reg_keyon[16];
                6'o51:  keyon <=                                        reg_keyon[17];
                6'o52:  keyon <=                                        reg_keyon[15];
                6'o53:  keyon <=                                        reg_keyon[16];
                6'o54:  keyon <=                                        reg_keyon[17];
                default:keyon <= 0;
            endcase
        end
    end

    always @(posedge clk, posedge rst) begin
        if( rst ) begin
            block <= 0;
        end else if(cen) begin
            case ({group, sub})
                6'o55:  block <=                                        reg_block[ 0];
                6'o00:  block <=                                        reg_block[ 1];
                6'o01:  block <=                                        reg_block[ 2];
                6'o02:  block <=                                        reg_block[ 0];
                6'o03:  block <=                                        reg_block[ 1];
                6'o04:  block <=                                        reg_block[ 2];

                6'o05:  block <= (new_en & consel[0]) ? reg_block[ 0] : reg_block[ 3];
                6'o10:  block <= (new_en & consel[1]) ? reg_block[ 1] : reg_block[ 4];
                6'o11:  block <= (new_en & consel[2]) ? reg_block[ 2] : reg_block[ 5];
                6'o12:  block <= (new_en & consel[0]) ? reg_block[ 0] : reg_block[ 3];
                6'o13:  block <= (new_en & consel[1]) ? reg_block[ 1] : reg_block[ 4];
                6'o14:  block <= (new_en & consel[2]) ? reg_block[ 2] : reg_block[ 5];

                6'o15:  block <=                                        reg_block[ 6];
                6'o20:  block <=                                        reg_block[ 7];
                6'o21:  block <=                                        reg_block[ 8];
                6'o22:  block <=                                        reg_block[ 6];
                6'o23:  block <=                                        reg_block[ 7];
                6'o24:  block <=                                        reg_block[ 8];

                6'o25:  block <=                                        reg_block[ 9];
                6'o30:  block <=                                        reg_block[10];
                6'o31:  block <=                                        reg_block[11];
                6'o32:  block <=                                        reg_block[ 9];
                6'o33:  block <=                                        reg_block[10];
                6'o34:  block <=                                        reg_block[11];

                6'o35:  block <= (new_en & consel[3]) ? reg_block[ 9] : reg_block[12];
                6'o40:  block <= (new_en & consel[4]) ? reg_block[10] : reg_block[13];
                6'o41:  block <= (new_en & consel[5]) ? reg_block[11] : reg_block[14];
                6'o42:  block <= (new_en & consel[3]) ? reg_block[ 9] : reg_block[12];
                6'o43:  block <= (new_en & consel[4]) ? reg_block[10] : reg_block[13];
                6'o44:  block <= (new_en & consel[5]) ? reg_block[11] : reg_block[14];

                6'o45:  block <=                                        reg_block[15];
                6'o50:  block <=                                        reg_block[16];
                6'o51:  block <=                                        reg_block[17];
                6'o52:  block <=                                        reg_block[15];
                6'o53:  block <=                                        reg_block[16];
                6'o54:  block <=                                        reg_block[17];
                default:block <= 0;
            endcase
        end
    end

    always @(posedge clk, posedge rst) begin
        if( rst ) begin
            fnum <= 0;
        end else if(cen) begin
            case ({group, sub})
                6'o55:  fnum <=                                       reg_fnum[ 0];
                6'o00:  fnum <=                                       reg_fnum[ 1];
                6'o01:  fnum <=                                       reg_fnum[ 2];
                6'o02:  fnum <=                                       reg_fnum[ 0];
                6'o03:  fnum <=                                       reg_fnum[ 1];
                6'o04:  fnum <=                                       reg_fnum[ 2];

                6'o05:  fnum <= (new_en & consel[0]) ? reg_fnum[ 0] : reg_fnum[ 3];
                6'o10:  fnum <= (new_en & consel[1]) ? reg_fnum[ 1] : reg_fnum[ 4];
                6'o11:  fnum <= (new_en & consel[2]) ? reg_fnum[ 2] : reg_fnum[ 5];
                6'o12:  fnum <= (new_en & consel[0]) ? reg_fnum[ 0] : reg_fnum[ 3];
                6'o13:  fnum <= (new_en & consel[1]) ? reg_fnum[ 1] : reg_fnum[ 4];
                6'o14:  fnum <= (new_en & consel[2]) ? reg_fnum[ 2] : reg_fnum[ 5];

                6'o15:  fnum <=                                       reg_fnum[ 6];
                6'o20:  fnum <=                                       reg_fnum[ 7];
                6'o21:  fnum <=                                       reg_fnum[ 8];
                6'o22:  fnum <=                                       reg_fnum[ 6];
                6'o23:  fnum <=                                       reg_fnum[ 7];
                6'o24:  fnum <=                                       reg_fnum[ 8];

                6'o25:  fnum <=                                       reg_fnum[ 9];
                6'o30:  fnum <=                                       reg_fnum[10];
                6'o31:  fnum <=                                       reg_fnum[11];
                6'o32:  fnum <=                                       reg_fnum[ 9];
                6'o33:  fnum <=                                       reg_fnum[10];
                6'o34:  fnum <=                                       reg_fnum[11];

                6'o35:  fnum <= (new_en & consel[3]) ? reg_fnum[ 9] : reg_fnum[12];
                6'o40:  fnum <= (new_en & consel[4]) ? reg_fnum[10] : reg_fnum[13];
                6'o41:  fnum <= (new_en & consel[5]) ? reg_fnum[11] : reg_fnum[14];
                6'o42:  fnum <= (new_en & consel[3]) ? reg_fnum[ 9] : reg_fnum[12];
                6'o43:  fnum <= (new_en & consel[4]) ? reg_fnum[10] : reg_fnum[13];
                6'o44:  fnum <= (new_en & consel[5]) ? reg_fnum[11] : reg_fnum[14];

                6'o45:  fnum <=                                       reg_fnum[15];
                6'o50:  fnum <=                                       reg_fnum[16];
                6'o51:  fnum <=                                       reg_fnum[17];
                6'o52:  fnum <=                                       reg_fnum[15];
                6'o53:  fnum <=                                       reg_fnum[16];
                6'o54:  fnum <=                                       reg_fnum[17];
                default:fnum <= 0;
            endcase
        end
    end

    always @(posedge clk, posedge rst) begin
        if( rst ) begin
            fb <= 0;
        end else if(cen) begin
            case ({group, sub})
                6'o55:  fb <=                                     reg_fb[ 0];
                6'o00:  fb <=                                     reg_fb[ 1];
                6'o01:  fb <=                                     reg_fb[ 2];
                6'o02:  fb <=                                     reg_fb[ 0];
                6'o03:  fb <=                                     reg_fb[ 1];
                6'o04:  fb <=                                     reg_fb[ 2];

                6'o05:  fb <= (new_en & consel[0]) ? reg_fb[ 0] : reg_fb[ 3];
                6'o10:  fb <= (new_en & consel[1]) ? reg_fb[ 1] : reg_fb[ 4];
                6'o11:  fb <= (new_en & consel[2]) ? reg_fb[ 2] : reg_fb[ 5];
                6'o12:  fb <= (new_en & consel[0]) ? reg_fb[ 0] : reg_fb[ 3];
                6'o13:  fb <= (new_en & consel[1]) ? reg_fb[ 1] : reg_fb[ 4];
                6'o14:  fb <= (new_en & consel[2]) ? reg_fb[ 2] : reg_fb[ 5];

                6'o15:  fb <=                                     reg_fb[ 6];
                6'o20:  fb <=                                     reg_fb[ 7];
                6'o21:  fb <=                                     reg_fb[ 8];
                6'o22:  fb <=                                     reg_fb[ 6];
                6'o23:  fb <=                                     reg_fb[ 7];
                6'o24:  fb <=                                     reg_fb[ 8];

                6'o25:  fb <=                                     reg_fb[ 9];
                6'o30:  fb <=                                     reg_fb[10];
                6'o31:  fb <=                                     reg_fb[11];
                6'o32:  fb <=                                     reg_fb[ 9];
                6'o33:  fb <=                                     reg_fb[10];
                6'o34:  fb <=                                     reg_fb[11];

                6'o35:  fb <= (new_en & consel[3]) ? reg_fb[ 9] : reg_fb[12];
                6'o40:  fb <= (new_en & consel[4]) ? reg_fb[10] : reg_fb[13];
                6'o41:  fb <= (new_en & consel[5]) ? reg_fb[11] : reg_fb[14];
                6'o42:  fb <= (new_en & consel[3]) ? reg_fb[ 9] : reg_fb[12];
                6'o43:  fb <= (new_en & consel[4]) ? reg_fb[10] : reg_fb[13];
                6'o44:  fb <= (new_en & consel[5]) ? reg_fb[11] : reg_fb[14];

                6'o45:  fb <=                                     reg_fb[15];
                6'o50:  fb <=                                     reg_fb[16];
                6'o51:  fb <=                                     reg_fb[17];
                6'o52:  fb <=                                     reg_fb[15];
                6'o53:  fb <=                                     reg_fb[16];
                6'o54:  fb <=                                     reg_fb[17];
                default:fb <= 0;
            endcase
        end
    end

    always @(posedge clk, posedge rst) begin
        if( rst ) begin
            dac_en <= 0;
        end else if(cen & ~new_en) begin
            if(MODULE_COUNT > 1) begin
                case ({group, sub})
                    6'o55, 6'o00, 6'o01, 6'o02, 6'o03, 6'o04,
                    6'o05, 6'o10, 6'o11, 6'o12, 6'o13, 6'o14,
                    6'o15, 6'o20, 6'o21, 6'o22, 6'o23, 6'o24:  dac_en <= OPL2_1_DAC_OUT;
                    6'o25, 6'o30, 6'o31, 6'o32, 6'o33, 6'o34,
                    6'o35, 6'o40, 6'o41, 6'o42, 6'o43, 6'o44,
                    6'o45, 6'o50, 6'o51, 6'o52, 6'o53, 6'o54:  dac_en <= OPL2_2_DAC_OUT;
                    default:dac_en <= 0;
                endcase
            end
            else begin
                dac_en <= 4'b0011;
            end
        end else if(cen) begin
            case ({group, sub})
                6'o55:  dac_en <=                                         reg_dac_en[ 0];
                6'o00:  dac_en <=                                         reg_dac_en[ 1];
                6'o01:  dac_en <=                                         reg_dac_en[ 2];
                6'o02:  dac_en <=                                         reg_dac_en[ 0];
                6'o03:  dac_en <=                                         reg_dac_en[ 1];
                6'o04:  dac_en <=                                         reg_dac_en[ 2];

                6'o05:  dac_en <= (         consel[0]) ? reg_dac_en[ 0] : reg_dac_en[ 3];
                6'o10:  dac_en <= (         consel[1]) ? reg_dac_en[ 1] : reg_dac_en[ 4];
                6'o11:  dac_en <= (         consel[2]) ? reg_dac_en[ 2] : reg_dac_en[ 5];
                6'o12:  dac_en <= (         consel[0]) ? reg_dac_en[ 0] : reg_dac_en[ 3];
                6'o13:  dac_en <= (         consel[1]) ? reg_dac_en[ 1] : reg_dac_en[ 4];
                6'o14:  dac_en <= (         consel[2]) ? reg_dac_en[ 2] : reg_dac_en[ 5];

                6'o15:  dac_en <=                                         reg_dac_en[ 6];
                6'o20:  dac_en <=                                         reg_dac_en[ 7];
                6'o21:  dac_en <=                                         reg_dac_en[ 8];
                6'o22:  dac_en <=                                         reg_dac_en[ 6];
                6'o23:  dac_en <=                                         reg_dac_en[ 7];
                6'o24:  dac_en <=                                         reg_dac_en[ 8];

                6'o25:  dac_en <=                                         reg_dac_en[ 9];
                6'o30:  dac_en <=                                         reg_dac_en[10];
                6'o31:  dac_en <=                                         reg_dac_en[11];
                6'o32:  dac_en <=                                         reg_dac_en[ 9];
                6'o33:  dac_en <=                                         reg_dac_en[10];
                6'o34:  dac_en <=                                         reg_dac_en[11];

                6'o35:  dac_en <= (         consel[3]) ? reg_dac_en[ 9] : reg_dac_en[12];
                6'o40:  dac_en <= (         consel[4]) ? reg_dac_en[10] : reg_dac_en[13];
                6'o41:  dac_en <= (         consel[5]) ? reg_dac_en[11] : reg_dac_en[14];
                6'o42:  dac_en <= (         consel[3]) ? reg_dac_en[ 9] : reg_dac_en[12];
                6'o43:  dac_en <= (         consel[4]) ? reg_dac_en[10] : reg_dac_en[13];
                6'o44:  dac_en <= (         consel[5]) ? reg_dac_en[11] : reg_dac_en[14];

                6'o45:  dac_en <=                                         reg_dac_en[15];
                6'o50:  dac_en <=                                         reg_dac_en[16];
                6'o51:  dac_en <=                                         reg_dac_en[17];
                6'o52:  dac_en <=                                         reg_dac_en[15];
                6'o53:  dac_en <=                                         reg_dac_en[16];
                6'o54:  dac_en <=                                         reg_dac_en[17];
                default:dac_en <= 0;
            endcase
        end
    end

end else begin
    always @(posedge clk, posedge rst) begin
            if( rst ) begin
            keyon  <= 0;
            block  <= 0;
            fnum   <= 0;
            fb     <= 0;
            con    <= 0;
            dac_en <= 0;
        end else if(cen) begin
            keyon <= reg_keyon [cur];
            block <= reg_block [cur];
            fnum  <= reg_fnum  [cur];
            fb    <= reg_fb    [cur];
            con   <= reg_con   [cur];
            dac_en<= reg_dac_en[cur];
        end
    end
end
endgenerate

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        reg_keyon <= 0;
        reg_con   <= 0;
        for( i=0; i<9; i=i+1 ) begin
            reg_block [i] <= 0;
            reg_fnum  [i] <= 0;
            reg_dac_en[i] <= 0;
        end
    end else if(cen) begin
        i = 0;
        if( up_fnumlo ) reg_fnum[up_ch][7:0] <= din;
        if( up_fnumhi ) { reg_keyon[up_ch], reg_block[up_ch], reg_fnum[up_ch][9:8] } <= din[5:0];
        if( up_fbcon  ) { reg_dac_en[up_ch], reg_fb[up_ch], reg_con[up_ch] } <= din[7:0];
    end
end

generate if(MODULE_COUNT > 1) begin

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        rhy_csr <= 6'd0;
        rhy_oen <= 0;
    end else if(cen) begin
        if(slot[SLOT_RHY_START - 1]) begin
            rhy_csr <= { rhy_kon[0][BD], rhy_kon[0][HH], rhy_kon[0][TOM],
                         rhy_kon[0][BD], rhy_kon[0][SD], rhy_kon[0][TC] };
            rhy_oen <= rhy_en[0];
        end else if(slot[SLOT_RHY_END]) begin
            rhy_oen <= 0;
        end else if(slot[SLOT_RHY_START - 1 + 18]) begin
            rhy_csr <= { rhy_kon[1][BD], rhy_kon[1][HH], rhy_kon[1][TOM],
                         rhy_kon[1][BD], rhy_kon[1][SD], rhy_kon[1][TC] };
            rhy_oen <= rhy_en[1] & ~new_en;
        end else if(slot[SLOT_RHY_END + 18]) begin
            rhy_oen <= 0;
        end else if(rhy_oen) begin
            rhy_csr <= { rhy_csr[4:0], rhy_csr[5] };
        end
    end
end

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        bd0_en <= 0;
        hh_en  <= 0;
        sd_en  <= 0;
        tc_en  <= 0;
    end else if(cen) begin
        bd0_en <= slot[(SLOT_RHY_BD0 - 1 + SLOTS) % SLOTS] | (slot[(SLOT_RHY_BD0 - 1 + SLOTS + 18) % SLOTS] & ~new_en);
        hh_en  <= slot[(SLOT_RHY_HH  - 1 + SLOTS) % SLOTS] | (slot[(SLOT_RHY_HH  - 1 + SLOTS + 18) % SLOTS] & ~new_en);
        sd_en  <= slot[(SLOT_RHY_SD  - 1 + SLOTS) % SLOTS] | (slot[(SLOT_RHY_SD  - 1 + SLOTS + 18) % SLOTS] & ~new_en);
        tc_en  <= slot[(SLOT_RHY_TC  - 1 + SLOTS) % SLOTS] | (slot[(SLOT_RHY_TC  - 1 + SLOTS + 18) % SLOTS] & ~new_en);
    end
end

always @(posedge clk) begin
    if(cen) begin
        if(group == 5 && sub == 5) begin
            am_dep_I <= am_dep[0];
            vib_dep_I <= vib_dep[0];
        end
        else if(group == 2 && sub == 5) begin
            am_dep_I <= am_dep[new_en ? 0 : 1];
            vib_dep_I <= vib_dep[new_en ? 0 : 1];
        end
    end
end

end else begin

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        rhy_csr <= 6'd0;
        rhy_oen <= 0;
    end else if(cen) begin
        if(slot[SLOT_RHY_START - 1]) rhy_oen <= rhy_en[0];
        if(slot[SLOT_RHY_END]) begin
            rhy_csr <= { rhy_kon[0][BD], rhy_kon[0][HH], rhy_kon[0][TOM],
                         rhy_kon[0][BD], rhy_kon[0][SD], rhy_kon[0][TC] };
            rhy_oen <= 0;
        end else
            rhy_csr <= { rhy_csr[4:0], rhy_csr[5] };
    end
end

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        bd0_en <= 0;
        hh_en  <= 0;
        sd_en  <= 0;
        tc_en  <= 0;
    end else if(cen) begin
        bd0_en <= slot[(SLOT_RHY_BD0 - 1 + SLOTS) % SLOTS];
        hh_en  <= slot[(SLOT_RHY_HH  - 1 + SLOTS) % SLOTS];
        sd_en  <= slot[(SLOT_RHY_SD  - 1 + SLOTS) % SLOTS];
        tc_en  <= slot[(SLOT_RHY_TC  - 1 + SLOTS) % SLOTS];
    end
end

always @(posedge clk) begin
    am_dep_I <= am_dep[0];
    vib_dep_I <= vib_dep[0];
end

end
endgenerate

endmodule