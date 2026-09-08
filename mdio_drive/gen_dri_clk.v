/*******************************************************************************
  ██████╗ ████████╗ ██████╗     ██████╗ ███████╗███████╗██╗ ██████╗ ███╗   ██╗
 ██╔════╝ ╚══██╔══╝██╔════╝     ██╔══██╗██╔════╝██╔════╝██║██╔════╝ ████╗  ██║
 ██║  ███╗   ██║   ██║          ██║  ██║█████╗  ███████╗██║██║  ███╗██╔██╗ ██║
 ██║   ██║   ██║   ██║          ██║  ██║██╔══╝  ╚════██║██║██║   ██║██║╚██╗██║
 ╚██████╔╝   ██║   ╚██████╔╝    ██████╔╝███████╗███████║██║╚██████╔╝██║ ╚████║
  ╚═════╝    ╚═╝    ╚═════╝     ╚═════╝ ╚══════╝╚══════╝╚═╝ ╚═════╝ ╚═╝  ╚═══╝
 *******************************************************************************/
/*      brief:  gen_dri_clk.v
        time:   2026-08-11
*/

module gen_dri_clk #(
        parameter       MDC_CLK_DIV = 6'd48
)(
        // system signal define
        input   wire            sys_clk,
        input   wire            sys_rst_n,
        // user en mdc_clk
        input   wire            en_mdc_clk,
        // output clk define
        output  wire            dri_clk,        // clk to drive user operation(double the frequency of mdc_clk)
        output  wire            mdc_clk         // clk to drive mdio operation(about 1Mhz)
);
        // buffer reg define
        reg[5:0]        cnt;
        localparam      CNT_MAX = MDC_CLK_DIV>>2;
        // the logic of counting
        always @(posedge sys_clk, negedge sys_rst_n) begin
                if(!sys_rst_n)                  cnt <= 6'b0;
                else if(cnt == CNT_MAX-1)       cnt <= 6'b0;
                else                            cnt <= cnt+1;
        end
        // output the dri_clk
        reg     reg_dri_clk;
        always @(posedge sys_clk, negedge sys_rst_n) begin
                if(!sys_rst_n)                  reg_dri_clk <= 1'b0;
                else if(cnt == CNT_MAX-1)       reg_dri_clk <= ~reg_dri_clk;
        end
        assign dri_clk = reg_dri_clk;
        
        // output the mdc_clk
        reg     reg_mdc_clk;
        always @(posedge reg_dri_clk, negedge sys_rst_n) begin
                if(!sys_rst_n)  reg_mdc_clk <= 1'b0;
                else            reg_mdc_clk <= ~reg_mdc_clk;
        end
        assign mdc_clk = en_mdc_clk ? reg_mdc_clk: 1'b0;

endmodule
