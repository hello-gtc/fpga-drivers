/*******************************************************************************
  ██████╗ ████████╗ ██████╗     ██████╗ ███████╗███████╗██╗ ██████╗ ███╗   ██╗
 ██╔════╝ ╚══██╔══╝██╔════╝     ██╔══██╗██╔════╝██╔════╝██║██╔════╝ ████╗  ██║
 ██║  ███╗   ██║   ██║          ██║  ██║█████╗  ███████╗██║██║  ███╗██╔██╗ ██║
 ██║   ██║   ██║   ██║          ██║  ██║██╔══╝  ╚════██║██║██║   ██║██║╚██╗██║
 ╚██████╔╝   ██║   ╚██████╔╝    ██████╔╝███████╗███████║██║╚██████╔╝██║ ╚████║
  ╚═════╝    ╚═╝    ╚═════╝     ╚═════╝ ╚══════╝╚══════╝╚═╝ ╚═════╝ ╚═╝  ╚═══╝
 *******************************************************************************/
/*  brief:  实现 sim_div.v
    time:   2026-08-08
*/ 

`timescale      1ns/1ps         // 时间单位1ns,时间精度1ps

module sim_div(

);
        // define data
        localparam      DATA_SIZE       = 12;
        localparam      data_size = DATA_SIZE/2;

        wire[data_size-1:0]     DIVIDEND        = 57;    // 被除数
        wire[data_size-1:0]     DIVISOR         = 4;    // 除数

        // basical signal generation 
        reg     sys_clk;
        reg     sys_rst_n;
        reg     en;
        
        // 时钟产生
        initial begin
                sys_clk         = 1'b0;
                forever #10     sys_clk = ~sys_clk;                    
        end
        // 复位信号
        initial begin
                sys_rst_n       = 1'b1;
                # 20;
                sys_rst_n       = 1'b0;
                # 100;
                sys_rst_n       = 1'b1; 
        end
        // 使能信号
        initial begin
                en      = 1'b0;
                # 200;
                en      = 1'b1;
                # 40;
                en      = 1'b0;
                # 1000
                $finish;
        end

        wire                    ready;
        wire[DATA_SIZE-1:0]     quotient;
        wire[DATA_SIZE-1:0]     remainder;
        wire                    vld_out;

        
        div_model  #(.DATA_WIDTH        (DATA_SIZE)
        )U_div_model(
                     .sys_clk           (sys_clk),
                     .sys_rst_n         (sys_rst_n),
                     .en                (en),
                     .dividend          (DIVIDEND),   
                     .divisor           (DIVISOR),

                     .ready             (ready),
                     .quotient          (quotient),
                     .remainder         (remainder),
                     .vld_out           (vld_out)
        );



endmodule
