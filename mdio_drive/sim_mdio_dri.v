/*******************************************************************************
  ██████╗ ████████╗ ██████╗     ██████╗ ███████╗███████╗██╗ ██████╗ ███╗   ██╗
 ██╔════╝ ╚══██╔══╝██╔════╝     ██╔══██╗██╔════╝██╔════╝██║██╔════╝ ████╗  ██║
 ██║  ███╗   ██║   ██║          ██║  ██║█████╗  ███████╗██║██║  ███╗██╔██╗ ██║
 ██║   ██║   ██║   ██║          ██║  ██║██╔══╝  ╚════██║██║██║   ██║██║╚██╗██║
 ╚██████╔╝   ██║   ╚██████╔╝    ██████╔╝███████╗███████║██║╚██████╔╝██║ ╚████║
  ╚═════╝    ╚═╝    ╚═════╝     ╚═════╝ ╚══════╝╚══════╝╚═╝ ╚═════╝ ╚═╝  ╚═══╝
 *******************************************************************************/
/*      brief:  sim_mdio_drive.v
        time:   2026-08-31
*/

`timescale      1ns/1ps

module  sim_mdio_dri();
        
        parameter       PHY_ADDR = 5'h04;       // PHY address

        
        reg             sys_clk;                // system signal define
        reg             sys_rst_n;

        wire            eth_mdc;                // mdio wire
        wire            eth_mdio;
        pullup(eth_mdio);

//--------------------------------------------------------------- instantiate the module
        reg             op_exec;                // mdio user signal define
        reg             op_rh_wl;
        reg[4:0]        op_addr;
        reg[15:0]       op_wr_data;
        
        wire            op_done;                // mdio slave signal define
        wire[15:0]      op_rd_data;
        wire            op_rd_ack;
        wire            dri_clk;
        
        mdio_dri u_mdio_dri(
                .sys_clk        (sys_clk),
                .sys_rst_n      (sys_rst_n),
                .op_exec        (op_exec),
                .op_rh_wl       (op_rh_wl),
                .op_addr        (op_addr),
                .op_wr_data     (op_wr_data),
                .op_done        (op_done),
                .op_rd_data     (op_rd_data),
                .op_rd_ack      (op_rd_ack),
                .dri_clk        (dri_clk),
                .eth_mdc        (eth_mdc),
                .eth_mdio       (eth_mdio)
        );

//--------------------------------------------------------------- instantiate the module
        reg             phy_rst_n;
        reg             phy_rst;
        
        reg[7:0]        wb_address_i;
        reg[7:0]        wb_data_i;
        wire[7:0]       wb_data_o;
        reg             wb_strobe_i;
        reg             wb_we_i;
        wire            wb_ack_o;
        
        mdio_slave_interface u_mdio_slave_interface(
                .rst_n_i        (phy_rst_n),
                .mdc_i          (eth_mdc),
                .mdio           (eth_mdio),

                .clk_i          (dri_clk),
                .rst_i          (phy_rst),
                .address_i      (wb_address_i),
                .data_i         (wb_data_i),
                .data_o         (wb_data_o),
                .strobe_i       (wb_strobe_i),
                .we_i           (wb_we_i),
                .ack_o          (wb_ack_o)
        );

//--------------------------------------------------------------- wishbone initial configuration task
        task automatic wb_op(input [7:0] addr, input [7:0] data);
                begin
                        @(negedge dri_clk) begin                // enable to write in
                                wb_we_i         = 1'b1;
                                wb_address_i    = addr;
                                wb_data_i       = data;
                                wb_strobe_i     = 1'b1;
                        end
                        wait(wb_ack_o == 1'b1);                 // write have done
                        @(negedge dri_clk) begin                // disable to write in
                                wb_strobe_i     = 1'b0;
                                wb_we_i         = 1'b0;
                        end
                end
        endtask

//--------------------------------------------------------------- mdio operation task
        task automatic mdio_op(input rw, input[4:0] addr, input[15:0] data_w);
                begin
                        @(negedge dri_clk) begin
                                op_rh_wl        = rw;
                                op_addr         = addr;
                                op_wr_data      = data_w;
                                op_exec         = 1'b1;
                        end
                        repeat(2) @(negedge dri_clk);
                        op_exec = 1'b0;
                        wait(op_done == 1'b1);                  // wait the flag of ending  
                        repeat(2) @(negedge dri_clk);
                end
        endtask

//--------------------------------------------------------------- initial begin
        integer         err;
        localparam      data = 16'h1234;

        initial begin
                sys_clk         = 1'b0;
                forever #10     sys_clk = ~sys_clk;
        end

        initial begin
                sys_rst_n       = 1'b0;
                phy_rst         = 1'b1;
                phy_rst_n       = 1'b0;

                # 100;
                sys_rst_n       = 1'b1;
                # 500;
                phy_rst_n       = 1'b1;
                phy_rst         = 1'b0;
        end

        initial begin
                op_exec         = 1'b0;
                op_rh_wl        = 1'b0;
                op_addr         = 5'b0;
                op_wr_data      = 16'b0;
                wb_address_i    = 8'b0;
                wb_strobe_i     = 1'b0;
                wb_we_i         = 1'b0;
                err             = 0;

                // 1. write 16'h1234 to 5'h4 by wb
                repeat(1) @(negedge dri_clk);
                wb_op(8'h40, PHY_ADDR);

                // 2. write 16'h1234 to 5'h4 by mdio
                repeat(1) @(negedge dri_clk);
                mdio_op(1'b0, 5'h4, data);

                // 3. read the data in 5'h4 by mdio
                repeat(1) @(negedge dri_clk);
                mdio_op(1'b1, 5'h4, 16'h0000);


                if(op_rd_data == data) begin
                        $display("PASS: write/read reg4, got %04h", op_rd_data);
                end
                else begin
                        $display("FAIL: expect 1234, got %04h", op_rd_data);
                        err = 1'b1;
                end
                $finish;
        end


endmodule
