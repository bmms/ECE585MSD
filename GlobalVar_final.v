`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: Portland State University - ECE 585: Microprocessor System Design
// Engineer: Ben Schaeffer, Mahmoud Alshamrani, Mayur Desadla, Sanjay Sharma,
// 
// Create Date: 03/03/2014 
// Design Name: Global Parameters
// Module Name:  
// Project Name: Cache Simulator for Quark Soc x1000 with virtual memory
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

//Operations in TLB cache
real TotalOperations_TLB = 0;
integer TLBReads=0;
integer TLBWrites=0;
real TLB_HitCount=0;
real TLB_MissCount=0;
real TLB_HitRatio = 0;
real TLB_MissRatio = 0;
integer TLB_Flush=0;

//Operations in L1 cache
real TotalOperations_L1 = 0; 
integer CacheReads = 0;
integer CacheWrites = 0;
real L1_HitRatio = 0.0;
real L1_MissRatio = 0.0;
real L1_HitCount = 0;
real L1_MissCount = 0;
integer CacheInvalidations=0;
integer Memory_Reads = 0;

//file operations
integer file;
integer report_file;
integer report_file_TLB;
