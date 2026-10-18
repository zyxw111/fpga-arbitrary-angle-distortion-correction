// Independent diagnostic build entry; internal interfaces are not board pins.
module demo_lens_top(input pix_clk,input tx_clk,input rst_n,input enable,
 output [31:0] beat_count,frame_count,hash,output overflow);
vtop #(.DEMO_GROUP(1)) u_demo(.pix_clk(pix_clk),.tx_clk(tx_clk),.rst_n(rst_n),.enable(enable),
 .beat_count(beat_count),.frame_count(frame_count),.hash(hash),.overflow(overflow));
endmodule
