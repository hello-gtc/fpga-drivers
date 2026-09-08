/*******************************************************************************
  ██████╗ ████████╗ ██████╗     ██████╗ ███████╗███████╗██╗ ██████╗ ███╗   ██╗
 ██╔════╝ ╚══██╔══╝██╔════╝     ██╔══██╗██╔════╝██╔════╝██║██╔════╝ ████╗  ██║
 ██║  ███╗   ██║   ██║          ██║  ██║█████╗  ███████╗██║██║  ███╗██╔██╗ ██║
 ██║   ██║   ██║   ██║          ██║  ██║██╔══╝  ╚════██║██║██║   ██║██║╚██╗██║
 ╚██████╔╝   ██║   ╚██████╔╝    ██████╔╝███████╗███████║██║╚██████╔╝██║ ╚████║
  ╚═════╝    ╚═╝    ╚═════╝     ╚═════╝ ╚══════╝╚══════╝╚═╝ ╚═════╝ ╚═╝  ╚═══╝
 *******************************************************************************/
/*      brief:  mdio_ctrl.v
        time:   2026-09-01
*/

module mdio_ctrl(
        input   wire            clk,            // system clk(2Mhz)
        input   wire            rst_n,          // system rst_n
        
        input   wire            soft_rst_trig,  // user touch button to reset
        
        input   wire            op_done,        // from mdio_dri 
        input   wire[15:0]      op_rd_data,     
        input   wire            op_rd_ack,      

        output  reg             op_exec,        // to mdio_dri 
        output  reg             op_rh_wl,       
        output  reg[4:0]        op_addr,        
        output  reg[15:0]       op_wr_data,

        output  wire[1:0]       led             // to ctrl led
);

//-------------------------------------------------------------------------------- tap the start signal(soft_rst_trig)
        reg             rst_trig_d0;
        reg             rst_trig_d1;
        reg             rst_trig_d2;
        wire            pos_soft_rst_trig;
        
        always @(posedge clk, negedge rst_n) begin                      // tap logic
                if(!rst_n) begin
                        rst_trig_d0     <= 1'b0;
                        rst_trig_d1     <= 1'b0;
                        rst_trig_d2     <= 1'b0;
                end
                else begin
                        rst_trig_d0     <= soft_rst_trig;
                        rst_trig_d1     <= rst_trig_d0;
                        rst_trig_d2     <= rst_trig_d1;
                end
        end

        assign  pos_soft_rst_trig = rst_trig_d1 & (~rst_trig_d2);       // catch the posedge
        

//-------------------------------------------------------------------------------- time 80ms(20Mhz)
        parameter       TIMER_MAX = 160_000;
        reg[17:0]       time_cnt;
        reg             time_done_flag;             

        always @(posedge clk, negedge rst_n) begin
                if(!rst_n) begin
                        time_done_flag  <= 1'b0;
                        time_cnt        <= 16'b0;
                end
                else if(time_cnt == TIMER_MAX-1) begin
                        time_done_flag  <= 1'b1;
                        time_cnt        <= 16'b0;
                end
                else begin    
                        time_cnt        <= time_cnt + 1;
                        time_done_flag  <= 1'b0;
                end
        end
        
//-------------------------------------------------------------------------------- operation phy
        reg[1:0]        speed_status;   // 01:10Mbps、10:100Mbps、11:1000Mbps、00：err
        reg             link_err;
        reg[2:0]        flow_cnt;
        reg             rst_trig_flag;
        assign led = link_err ? 2'b00 : speed_status; 
        

        always @(posedge clk, negedge rst_n) begin
                if(!rst_n) begin
                        op_exec         <= 1'b0;
                        op_rh_wl        <= 1'b0;
                        op_addr         <= 5'b0;
                        op_wr_data      <= 16'b0;

                        link_err        <= 1'b0;
                        speed_status    <= 2'b00;

                        flow_cnt        <= 3'b0;
                        rst_trig_flag   <= 1'b0;
                end
                else begin
                        op_exec         <= 1'b0;
                        if(pos_soft_rst_trig)   rst_trig_flag <= 1'b1;
                        
                        case(flow_cnt) 
                                3'b000: begin
                                        if(rst_trig_flag) begin                 // write the data in oder to reset the phy by sofrware
                                                op_exec         <= 1'b1;
                                                op_rh_wl        <= 1'b0;
                                                op_addr         <= 5'h00;
                                                op_wr_data      <= 16'h9140;

                                                flow_cnt        <= 3'd1;
                                        end
                                        else if(time_done_flag == 1'b1) begin   // the flag to read the data in oder to get the phy mode 
                                                op_exec         <= 1'b1;
                                                op_rh_wl        <= 1'b1;
                                                op_addr         <= 5'h01;
                                                flow_cnt        <= 3'd2;
                                        end
                                end
                                3'b001: begin                   // write the data to reset
                                        if(op_done) begin
                                                flow_cnt        <= 3'b0;
                                                rst_trig_flag   <= 1'b0;
                                        end
                                end
                                3'b010: begin                   // read the link is ok or not
                                        if(op_done) begin
                                                if(op_rd_ack==1'b1 && op_rd_data[5]==1'b1 && op_rd_data[2]==1'b1) begin
                                                        flow_cnt        <= 3'd3;
                                                        link_err        <= 1'b0;
                                                end
                                                else begin
                                                        flow_cnt        <= 3'd0;
                                                        link_err        <= 1'b1;
                                                end
                                        end
                                end
                                3'b011: begin                   // read the speed mode
                                        op_exec         <= 1'b1;
                                        op_rh_wl        <= 1'b1;
                                        op_addr         <= 5'h11;
                                        
                                        flow_cnt        <= 3'd4;
                                end
                                3'b100: begin
                                        if(op_done) begin
                                                if(op_rd_ack == 1'b1)   flow_cnt <= 3'd5;
                                                else                    flow_cnt <= 3'd0;
                                        end
                                end
                                3'b101: begin
                                        flow_cnt        <= 3'd0;
                                        if(op_rd_data[15:14] == 2'b10)          speed_status <= 2'b11;  // 1000mbps;
                                        else if(op_rd_data[15:14] == 2'b01)     speed_status <= 2'b10;  // 100mbps;
                                        else if(op_rd_data[15:14] == 2'b00)     speed_status <= 2'b01;  // 10mbps;
                                        else                                    speed_status <= 2'b00;
                                end
                                default:        ;
                        endcase
                end
        end
endmodule

