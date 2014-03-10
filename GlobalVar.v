`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: Portland State University - ECE 585: Microprocessor System Design
// Engineer: Sanjay Sharma and Mayur Desadla
// 
// Create Date: 03/03/2014 
// Design Name: L1 cache design
// Module Name:  
// Project Name: Cache Simulator
// Target Devices: 
// Description: 
//
// Dependencies: 
//
// Revision: 1.0
// Additional Comments: 
//
//////////////////////////////////////////////////////////////////////////////////

`define EOF 32'hFFFF_FFFF
`define Null 0
`define Max_line_length 1000

////////////////////////////////////////////////
///////////// General declarations /////////////
////////////////////////////////////////////////

integer TotalOperations = 0;
integer CacheReads = 0;
integer CacheWrites = 0;
integer CacheFetches = 0;
real L1_HitRatio = 0.0;
real L1_MissRatio = 0.0;
integer L1_HitCount = 0;
integer L1_MissCount = 0;
integer file;
integer report_file,r;
