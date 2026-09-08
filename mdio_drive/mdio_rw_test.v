/*******************************************************************************
  ██████╗ ████████╗ ██████╗     ██████╗ ███████╗███████╗██╗ ██████╗ ███╗   ██╗
 ██╔════╝ ╚══██╔══╝██╔════╝     ██╔══██╗██╔════╝██╔════╝██║██╔════╝ ████╗  ██║
 ██║  ███╗   ██║   ██║          ██║  ██║█████╗  ███████╗██║██║  ███╗██╔██╗ ██║
 ██║   ██║   ██║   ██║          ██║  ██║██╔══╝  ╚════██║██║██║   ██║██║╚██╗██║
 ╚██████╔╝   ██║   ╚██████╔╝    ██████╔╝███████╗███████║██║╚██████╔╝██║ ╚████║
  ╚═════╝    ╚═╝    ╚═════╝     ╚═════╝ ╚══════╝╚══════╝╚═╝ ╚═════╝ ╚═╝  ╚═══╝
 *******************************************************************************/
/*      brief:  mdio_rw_test.v
        time:   2026-09-01
*/

module mdio_rw_test(
        input   wire            sys_clk,
        input   wire            sys_rst_n,
        
        output  wire            eth_mdc,
        inout   wire            eth_mdio,
        output  wire            eth_rst_n,

        input   wire            touch_key,
        output  wire[1:0]       led
);
        wire            op_exec;
        wire            op_rh_wl;
        wire[4:0]       op_addr;
        wire[15:0]      op_data_w;
        wire[15:0]      op_data_r;
        wire            op_done;
        wire            op_rd_ack;
        wire            dri_clk;

        assign  eth_rst_n = sys_rst_n;

        mdio_dri #(.PHY_ADDR(5'h04),
                   .MDC_CLK_DIV(6'd48)     
        )
        U_mdio_dri(
                .sys_clk        (sys_clk),
                .sys_rst_n      (sys_rst_n),
                .op_exec        (op_exec),
                .op_rh_wl       (op_rh_wl),
                .op_addr        (op_addr),
                .op_wr_data     (op_data_w),
                .op_done        (op_done),
                .op_rd_data     (op_data_r),
                .op_rd_ack      (op_rd_ack),
                .dri_clk        (dri_clk),

                .eth_mdc        (eth_mdc),
                .eth_mdio       (eth_mdio)
        );

        mdio_ctrl U_mdio_ctrl(
                .clk            (dri_clk),
                .rst_n          (sys_rst_n),
                .soft_rst_trig  (touch_key),
                
                .op_done        (op_done),
                .op_rd_data     (op_data_r),
                .op_rd_ack      (op_rd_ack),
                .op_exec        (op_exec),
                .op_rh_wl       (op_rh_wl),
                .op_addr        (op_addr),
                .op_wr_data     (op_data_w), 
                .led            (led)       
        );
/*
        ila_0 U_ila_0(
                .clk            (sys_clk),
                
                .probe0         (touch_key),
                .probe1         (sys_rst_n),
                .probe2         (op_exec),
                .probe3         (op_rh_wl),
                .probe4         (op_addr),
                .probe5         (op_data_w),
                .probe6         (op_data_r),
                .probe7         (op_done),
                .probe8         (op_rd_ack),
                .probe9         (eth_mdc),
                .probe10        (eth_mdio)
        );
*/


endmodule