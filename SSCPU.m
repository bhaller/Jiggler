//
//  SSCPUView.m
//  eyeballs
//
//  Created by bhaller on Wed Jun 06 2001.
//  Copyright (c) 2002 Ben Haller. All rights reserved.
//

#import "SSCPU.h"
#import "CocoaExtra.h"

#include <mach/mach.h>
#include <mach/processor_info.h>
#include <mach/processor.h>


int getCPUUsage(void);
void setupForCPUUsage(void);


// Variables used by both setup() and cpuUsage()

processor_cpu_load_info_t savedTicks;
unsigned int procs_count;
int live_processors_count;

int getCPUUsage(void)
{
    int i, j, pcount;
    processor_cpu_load_info_t ticks;
    mach_msg_type_number_t info_count;
    natural_t num_procs;
    kern_return_t ret;
    int load[2];

    ret = host_processor_info(mach_host_self(), 
			      PROCESSOR_CPU_LOAD_INFO, 
			      &num_procs,
			      (processor_info_array_t *)&ticks,
			      &info_count);
    
    pcount = ((live_processors_count > 2) ? 2 : live_processors_count);
    
    for (i = 0; i < pcount; i++)
    {
        struct processor_cpu_load_info deltas;
        unsigned long sum = 0;

        for (j = 0; j < CPU_STATE_MAX; j++) {
            deltas.cpu_ticks[j] = ticks[i].cpu_ticks[j] - savedTicks[i].cpu_ticks[j];
            savedTicks[i].cpu_ticks[j] = ticks[i].cpu_ticks[j];
            sum += deltas.cpu_ticks[j];
        }
		
        if (sum > 0) {
            load[i] = (1.0 - ((double)(deltas.cpu_ticks[CPU_STATE_IDLE]) / (double)sum)) * 100.0;
        } else {
            load[i] = 0.0;
        }
        
        if (load[i] > 100) { load[i] = 100; };
		
		NSLog(@"raw: user %d, system %d, idle %d, nice %d.", ticks[i].cpu_ticks[0], ticks[i].cpu_ticks[1], ticks[i].cpu_ticks[2], ticks[i].cpu_ticks[3]);
		
        NSLog(@"deltas: user %d, system %d, idle %d, nice %d.  Load == %d", deltas.cpu_ticks[0], deltas.cpu_ticks[1], deltas.cpu_ticks[2], deltas.cpu_ticks[3], load[i]);
    }
    
    vm_deallocate(mach_task_self(),
		  (vm_offset_t)savedTicks,
		  sizeof(struct processor_cpu_load_info) * procs_count);
    savedTicks = ticks;

    return ((pcount == 2) ? (load[0] + load[1]) / 2 : load[0]);
}

void setupForCPUUsage(void)
{
    int i;
    processor_basic_info_t procs_info;
    mach_msg_type_number_t procs_info_count;
    kern_return_t kr;
    
    //usleep(10000);
    
    live_processors_count = 0;
    
    kr = host_processor_info(mach_host_self(),
			     PROCESSOR_BASIC_INFO,
			     &procs_count,
			     (processor_info_array_t *)&procs_info,
			     &procs_info_count);
    
    for (i=0; i < procs_count; i++) {
	if (procs_info[i].running) {
	    live_processors_count++;
	}
    }
    
    vm_deallocate(mach_task_self(),
		  (vm_offset_t)procs_info,
		  (vm_size_t)(procs_info_count * sizeof(int)));

    kr = host_processor_info(mach_host_self(),
			     PROCESSOR_CPU_LOAD_INFO,
			     &procs_count,
			     (processor_info_array_t *)&savedTicks,
			     &procs_info_count);
}

@implementation SSCPU

+ (int)busyIndex
{
    static BOOL beenHereDoneThat = NO;
    
    if (!beenHereDoneThat)
    {
        setupForCPUUsage();
        beenHereDoneThat = YES;
    }
    
    return getCPUUsage();
}

@end
