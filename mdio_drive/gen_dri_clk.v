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
        parameter       CLK_DIV = 6'd48
)(
        input   wire            sys_clk,
        input   wire            sys_rst_n,
        
        output  wire            dri_clk,        // clk to drive user operation(2Mhz)
        output  wire            mdc_clk         // clk to drive mdio operation(1Mhz)
);
        // reg define
        reg[5:0]        clk_cnt;

        // count logic
        always @(posedge sys_clk, negedge sys_rst_n) begin
                if(!sys_rst_n)  begin
                        clk_cnt <= 6'b0; 
                end
                else begin
                        if(clk_cnt < CLK_DIV-1)         clk_cnt <= clk_cnt + 1;
                        else                            clk_cnt <= 6'b0; 
                end
        end
        // reg define
        reg     reg_dri_clk;
        reg     reg_mdc_clk;

        // output logic
        always @(posedge sys_clk, negedge sys_rst_n) begin
                if(!sys_rst_n) begin
                        reg_dri_clk <= 1'b1;
                        reg_mdc_clk <= 1'b0;
                end
                else begin
                        if(clk_cnt == CLK_DIV/4-1)              reg_dri_clk <= ~reg_dri_clk;
                        else if(clk_cnt == CLK_DIV/2-1) begin      
                                                                reg_dri_clk <= ~reg_dri_clk;
                                                                reg_mdc_clk <= ~reg_mdc_clk;
                        end
                        else if(clk_cnt == (3*(CLK_DIV/4)-1))   reg_dri_clk <= ~reg_dri_clk;
                        else if(clk_cnt == CLK_DIV-1)   begin
                                                                reg_mdc_clk <= ~reg_mdc_clk;
                                                                reg_dri_clk <= ~reg_dri_clk;
                        end
                        else begin
                                                                reg_mdc_clk <= reg_mdc_clk;
                                                                reg_dri_clk <= reg_dri_clk;
                        end        
                end
        end

        assign  mdc_clk = reg_mdc_clk;
        assign  dri_clk = reg_dri_clk;

endmodule
