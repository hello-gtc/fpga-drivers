/*******************************************************************************
  ██████╗ ████████╗ ██████╗     ██████╗ ███████╗███████╗██╗ ██████╗ ███╗   ██╗
 ██╔════╝ ╚══██╔══╝██╔════╝     ██╔══██╗██╔════╝██╔════╝██║██╔════╝ ████╗  ██║
 ██║  ███╗   ██║   ██║          ██║  ██║█████╗  ███████╗██║██║  ███╗██╔██╗ ██║
 ██║   ██║   ██║   ██║          ██║  ██║██╔══╝  ╚════██║██║██║   ██║██║╚██╗██║
 ╚██████╔╝   ██║   ╚██████╔╝    ██████╔╝███████╗███████║██║╚██████╔╝██║ ╚████║
  ╚═════╝    ╚═╝    ╚═════╝     ╚═════╝ ╚══════╝╚══════╝╚═╝ ╚═════╝ ╚═╝  ╚═══╝
 *******************************************************************************/
/*  brief:  实现 iic_drive 
    time:   2026-07-27
*/ 

module iic_drive #(
        parameter               SLAVE_ADDR      =  7'b101_0000,         // 从机地址
        parameter               CLK_FREQ        = 26'd500_000_00,       // 输入时钟频率
        parameter               IIC_FREQ        = 18'd250_000           // 输出scl频率      
)(
        input   wire            sys_clk,        // 系统 输入时钟驱动
        input   wire            sys_rst_n,      // 系统 输入复位信号（低电平有效）

        input   wire            iic_exec,       // 控制 输入起始信号（高脉冲）
        input   wire            bit_ctrl,       // 控制 输入reg地址位数控制信号（1为16位，0为8位）
        input   wire            iic_rh_wl,      // 控制 输入读写控制信号
        input   wire[15:0]      reg_addr,       // 控制 输入寄存器地址
        input   wire[7:0]       iic_data_w,     // 控制 输入写入的数据

        output  reg[7:0]        iic_data_r,     // 主机 读取从从机的数据
        output  reg             iic_done,       // 完成iic通信的标志（高电平有效）
        output  reg             iic_ack,        // iic从机回应信号（高脉冲有效）

        output  wire            scl,            // 通信 scl时钟线
        inout   wire            sda             // 通信 sda数据线
);
//---------------------------------------------------------------------------------- 获取iic_exec信号（打两拍）
        // 变量定义
        wire            iic_exec_tap;           // 打两拍后的iic_exec信号
        reg             iic_exec_delay0;        // 打一拍
        reg             iic_exec_delay1;        // 打两拍
        
        // 打两拍逻辑
        always @(posedge sys_clk, negedge sys_rst_n) begin
                if(!sys_rst_n) begin
                        iic_exec_delay0 <= 1'b0;
                        iic_exec_delay1 <= 1'b0;
                end
                else begin
                        iic_exec_delay0 <= iic_exec;
                        iic_exec_delay1 <= iic_exec_delay0;
                end
        end
        
        // 赋值
        assign iic_exec_tap = iic_exec_delay1;


//---------------------------------------------------------------------------------- 数据寄存
        // 变量定义
        reg[15:0]       reg_addr_t;     // 寄存器地址寄存
        reg[7:0]        data_w_t;       // 将要写数据寄存
        reg             iic_rh_wl_t;    // 读写控制信号寄存

        // 寄存逻辑
        always @(posedge sys_clk, negedge sys_rst_n) begin
                if(!sys_rst_n) begin
                        reg_addr_t      <= 16'd0;
                        data_w_t        <=  8'd0;
                        iic_rh_wl_t     <=  1'bz;
                end
                else begin
                        if(iic_exec_tap) begin
                                reg_addr_t      <= reg_addr;
                                data_w_t        <= iic_data_w;
                                iic_rh_wl_t     <= iic_rh_wl;
                        end
                        else begin
                                reg_addr_t      <= reg_addr_t;
                                data_w_t        <= data_w_t;
                                iic_rh_wl_t     <= iic_rh_wl_t;
                        end
                end
        end


//---------------------------------------------------------------------------------- 状态机定义
        localparam st_idle              = 8'b0000_0001;         // 空闲状态
        localparam st_slave_addr        = 8'b0000_0010;         // 发送从机地址
        localparam st_addr_16           = 8'b0000_0100;         // 发送寄存器高8位
        localparam st_addr_8            = 8'b0000_1000;         // 发送寄存器低8位
        localparam st_data_wr           = 8'b0001_0000;         // 发送写数据
        localparam st_addr_rd           = 8'b0010_0000;         // 虚写结束后，发送读命令
        localparam st_data_rd           = 8'b0100_0000;         // 接收读数据
        localparam st_stop              = 8'b1000_0000;         // 发送停止命令

        reg[7:0]        curr_state;     // 目前状态
        reg[7:0]        next_state;     // 下一个状态


//---------------------------------------------------------------------------------- 数据线控制
        // 变量定义
        reg             sda_dir;        // sda 方向控制（1为out,0为in）
        reg             sda_out;        // sda 输出的数据
        wire            sda_in;         // sda 接收的数据     
        
        // sda输出输入转换逻辑
        assign sda      = sda_dir ? sda_out : 1'bz;     // 输出sda_out数据 或者 释放sda
        assign sda_in   = sda;                          // sda_in 一直接收sda数据


//---------------------------------------------------------------------------------- 产生时钟
        // 变量定义
        reg             scl_en;         // scl使能信号（高电平有效）
        wire            iic_opera_clk;  // iic 驱动操作时钟

        // 实例化 
        iic_gen_clk #(
                .CLK_FREQ       (CLK_FREQ),
                .IIC_FREQ       (IIC_FREQ)
        ) U_iic_gen_clk (
                .clk            (sys_clk),
                .rst_n          (sys_rst_n),
                .scl_ctrl       (scl_en),
                .scl            (scl),
                .iic_opera_clk  (iic_opera_clk)
        );


//---------------------------------------------------------------------------------- 状态机转移 同步时序
        always @(posedge iic_opera_clk, negedge sys_rst_n) begin
                if(!sys_rst_n) begin
                        curr_state      <= st_idle;
                        next_state      <= st_idle;
                end
                else begin
                        curr_state      <= next_state;
                end
        end


//---------------------------------------------------------------------------------- 状态机转移   组合逻辑
        // 变量定义
        reg             st_done;        // 每个状态机完成标志

        always @(*) begin
                next_state      = st_idle;
                
                case(curr_state)
                        st_idle:        begin
                                if(iic_exec_tap)        next_state = st_slave_addr;
                                else                    next_state = st_idle;
                        end
                        st_slave_addr:  begin
                                if(st_done)             next_state = bit_ctrl ? st_addr_16 : st_addr_8;
                                else                    next_state = st_slave_addr;
                        end
                        st_addr_16:     begin
                                if(st_done)             next_state = st_addr_8;
                                else                    next_state = st_addr_16;
                        end
                        st_addr_8:      begin
                                if(st_done)             next_state = iic_rh_wl_t ? st_addr_rd : st_data_wr;
                                else                    next_state = st_addr_8;
                        end
                        st_addr_rd:     begin
                                if(st_done)             next_state = st_data_rd;
                                else                    next_state = st_addr_rd;
                        end
                        st_data_wr:     begin
                                if(st_done)             next_state = st_stop;
                                else                    next_state = st_data_wr;
                        end
                        st_data_rd:     begin
                                if(st_done)             next_state = st_stop;
                                else                    next_state = st_data_rd;
                        end
                        st_stop:        begin
                                if(iic_done)            next_state = st_idle;
                                else                    next_state = st_stop;
                        end
                        default:        next_state = st_idle;
                endcase
        end


//---------------------------------------------------------------------------------- scl_en 逻辑
        reg[5:0]                bit_cnt;        // 单比特计数器
       
        always @(posedge sys_clk, negedge sys_rst_n) begin
                if(!sys_rst_n)                                  scl_en  <= 1'b0;
                else if(iic_exec_tap)                           scl_en  <= 1'b1;
                else if(curr_state==st_addr_rd && bit_cnt==2)   scl_en  <= 1'b0;
                else if(curr_state==st_addr_rd && bit_cnt==3)   scl_en  <= 1'b1;
                else if(curr_state==st_stop && bit_cnt==2)      scl_en  <= 1'b0;
        end


//---------------------------------------------------------------------------------- 状态输出，时序描述
        // 变量定义

        always @(posedge iic_opera_clk, negedge sys_rst_n) begin
                if(!sys_rst_n) begin
                        iic_data_r      <= 8'b0;
                        iic_done        <= 1'b0;
                        iic_ack         <= 1'b0;
                        sda_dir         <= 1'b0;
                        sda_out         <= 1'b1;

                        bit_cnt         <= 6'b0;
                        st_done         <= 1'b0;
                end
                else begin
                        case(curr_state)
                                st_idle:        begin
                                        iic_data_r      <= 8'b0;        // 上层 读信号输出0
                                        iic_done        <= 1'b0;        // 上层 操作完成信号输出0
                                        iic_ack         <= 1'b0;        // 上层 单步操作完成信号输出0
                                        sda_dir         <= 1'b0;        // 上层 主机释放sda 
                                        sda_out         <= 1'b1;        

                                        bit_cnt         <= 6'b0;        // bit操作计数器为零
                                end
                                st_slave_addr:  begin
                                        bit_cnt         <= bit_cnt + 1; // 一直自加
                                        st_done         <= 1'b0;
                                        iic_ack         <= 1'b0;   
                                        
                                        case(bit_cnt)
                                                6'd0: begin
                                                        sda_dir <= 1'b1;                // 主机输出模式
                                                        sda_out <= 1'b0;                // 起始信号
                                                end
                                                6'd2:   sda_out <= SLAVE_ADDR[6];       // 写入地址
                                                6'd6:   sda_out <= SLAVE_ADDR[5];       // 
                                                6'd10:  sda_out <= SLAVE_ADDR[4];       // 
                                                6'd14:  sda_out <= SLAVE_ADDR[3];       // 
                                                6'd18:  sda_out <= SLAVE_ADDR[2];       // 
                                                6'd22:  sda_out <= SLAVE_ADDR[1];       // 
                                                6'd26:  sda_out <= SLAVE_ADDR[0];       // 
                                                6'd30:  sda_out <= 1'b0;         // 读写控制位
                                                6'd33: begin                            // 释放sda
                                                        sda_dir <= 1'b0;
                                                        sda_out <= 1'b1;
                                                end          
                                                6'd36: begin                            // 判断从机是否回应
                                                        if(sda_in == 1'b0)      iic_ack <= 1'b1;
                                                        else                    iic_ack <= 1'b0;
                                                        st_done <= 1'b1;
                                                        bit_cnt <= 6'b0;
                                                end
                                                default:        ;
                                        endcase
                                end
                                st_addr_16:     begin
                                        bit_cnt         <= bit_cnt + 1;
                                        st_done         <= 1'b0;
                                        iic_ack         <= 1'b0;
                                        
                                        case(bit_cnt)
                                                6'd1: begin   
                                                        sda_dir <= 1'b1;                // 写入寄存器地址高八位
                                                        sda_out <= reg_addr[15];
                                                end
                                                6'd5:   sda_out <= reg_addr[14];
                                                6'd9:   sda_out <= reg_addr[13];
                                                6'd13:  sda_out <= reg_addr[12];
                                                6'd17:  sda_out <= reg_addr[11];
                                                6'd21:  sda_out <= reg_addr[10];
                                                6'd25:  sda_out <= reg_addr[ 9];
                                                6'd29:  sda_out <= reg_addr[ 8];        
                                                6'd32: begin                            // 释放总线
                                                        sda_dir <= 1'b0;
                                                        sda_out <= 1'b1;
                                                end
                                                6'd35: begin                            // 判断从机是否应答
                                                        if(sda_in == 1'b0)      iic_ack <= 1'b1;
                                                        else                    iic_ack <= 1'b0;
                                                        st_done <= 1'b1;
                                                        bit_cnt <= 6'b0;
                                                end     
                                        endcase
                                end
                                st_addr_8:      begin
                                        bit_cnt         <= bit_cnt + 1;
                                        st_done         <= 1'b0;
                                        iic_ack         <= 1'b0;
                                  
                                        case(bit_cnt)
                                                6'd1: begin                             // 输出寄存器地址低八位
                                                        sda_dir <= 1'b1;
                                                        sda_out <= reg_addr[ 7];
                                                end
                                                6'd5:   sda_out <= reg_addr[ 6];
                                                6'd9:   sda_out <= reg_addr[ 5];
                                                6'd13:  sda_out <= reg_addr[ 4];
                                                6'd17:  sda_out <= reg_addr[ 3];
                                                6'd21:  sda_out <= reg_addr[ 2];
                                                6'd25:  sda_out <= reg_addr[ 1];
                                                6'd29:  sda_out <= reg_addr[ 0];
                                                6'd32: begin                            // 释放总线
                                                        sda_dir <= 1'b0;
                                                        sda_out <= 1'b1;
                                                end
                                                6'd35: begin                            // 判断从机是否应答
                                                        if(sda_in == 1'b0)      iic_ack <= 1'b1;
                                                        else                    iic_ack <= 1'b0;
                                                        st_done <= 1'b1;
                                                        bit_cnt <= 6'b0;
                                                end
                                        endcase
                                end
                                st_data_wr:     begin
                                        bit_cnt         <= bit_cnt + 1;
                                        st_done         <= 1'b0;
                                        iic_ack         <= 1'b0;

                                        case(bit_cnt)
                                                6'd1: begin                             // 写入数据 高位到低位
                                                        sda_dir <= 1'b1;
                                                        sda_out <= iic_data_w[ 7];
                                                end
                                                6'd5:   sda_out <= iic_data_w[ 6];
                                                6'd9:   sda_out <= iic_data_w[ 5];
                                                6'd13:  sda_out <= iic_data_w[ 4];
                                                6'd17:  sda_out <= iic_data_w[ 3];
                                                6'd21:  sda_out <= iic_data_w[ 2];
                                                6'd25:  sda_out <= iic_data_w[ 1];
                                                6'd29:  sda_out <= iic_data_w[ 0];
                                                6'd32: begin                            // 释放总线
                                                        sda_dir <= 1'b0;
                                                        sda_out <= 1'b1;
                                                end
                                                6'd35: begin                            // 判断从机是否应答
                                                        if(sda_in == 1'b0)      iic_ack <= 1'b1;
                                                        else                    iic_ack <= 1'b0;
                                                        st_done <= 1'b1;
                                                        bit_cnt <= 6'b0;
                                                end
                                        endcase
                                end



                                ////////////////////////////////////////////////////////////
                                st_addr_rd:     begin
                                        bit_cnt         <= bit_cnt + 1;
                                        st_done         <= 1'b0;
                                        iic_ack         <= 1'b0;
                                
                                        case(bit_cnt)
                                                6'd4: begin                             // 写入 从机地址
                                                        sda_dir <= 1'b1;
                                                        sda_out <= 1'b0;
                                                end
                                                6'd6:   sda_out <= SLAVE_ADDR[6];
                                                6'd10:  sda_out <= SLAVE_ADDR[5];
                                                6'd14:  sda_out <= SLAVE_ADDR[4];
                                                6'd18:  sda_out <= SLAVE_ADDR[3];
                                                6'd22:  sda_out <= SLAVE_ADDR[2];
                                                6'd26:  sda_out <= SLAVE_ADDR[1];
                                                6'd30:  sda_out <= SLAVE_ADDR[0];
                                                6'd34:  sda_out <= 1'b1;                // 写入读信号
                                                6'd37: begin                            // 释放总线：从机应答
                                                        sda_dir <= 1'b0;
                                                        sda_out <= 1'b1;
                                                end
                                                6'd40: begin                            // 判断从机是否应答
                                                        if(sda_in == 1'b0)      iic_ack <= 1'b1;
                                                        else                    iic_ack <= 1'b0;
                                                        st_done <= 1'b1;
                                                        bit_cnt <= 6'b0;
                                                end

                                        endcase
                                end

                                st_data_rd:     begin
                                        bit_cnt         <= bit_cnt + 1;
                                        st_done         <= 1'b0;
                                        iic_ack         <= 1'b0;

                                        case(bit_cnt)
                                                6'd1: begin
                                                        sda_dir <= 1'b0;
                                                        sda_out <= 1'b1;
                                                end
                                                6'd3:   iic_data_r[7] <= sda_in;
                                                6'd7:   iic_data_r[6] <= sda_in;
                                                6'd11:  iic_data_r[5] <= sda_in;
                                                6'd15:  iic_data_r[4] <= sda_in;
                                                6'd19:  iic_data_r[3] <= sda_in;
                                                6'd23:  iic_data_r[2] <= sda_in;
                                                6'd27:  iic_data_r[1] <= sda_in;
                                                6'd31:  iic_data_r[0] <= sda_in;
                                                6'd33: begin                            // 获取总线：主机非应答
                                                        sda_dir <= 1'b1;
                                                        sda_out <= 1'b1;
                                                end
                                                6'd35: begin                            // 判断从机是否应答
                                                        st_done <= 1'b1;
                                                        bit_cnt <= 6'b0;
                                                end

                        
                                        endcase
                                end
                                ////////////////////////////////////////////////////////////



                                st_stop:        begin
                                        bit_cnt         <= bit_cnt + 1;
                                        st_done         <= 1'b0;
                                        iic_ack         <= 1'b0;

                                        case(bit_cnt)
                                                6'd1: begin
                                                        sda_dir         <= 1'b1;
                                                        sda_out         <= 1'b0;
                                                end 
                                                6'd4: begin
                                                        sda_out         <= 1'b1;
                                                        iic_done        <= 1'b1;
                                                end
                                                default:        ;
                                        endcase        
                                end      
                        endcase
                end
        end
endmodule


