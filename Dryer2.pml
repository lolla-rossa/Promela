	#define handOn sensor == on
    #define dryerOn dryer == on
    #define handOff sensor == off
    #define dryerOff dryer == off
    #define nTime localTime == 10
    #define flagT flagTime == true
	
	mtype: procState = {pOn, pOff, pStop, pError};
	mtype: dryerState = {on, off};
	
	mtype:dryerState sensor;
	mtype:dryerState dryer;
	mtype:procState prosState;
	
	short processCount = 2;
	mtype:process = {procDr, procT, procS};
	mtype:process activeProcesses[processCount];
    short globalTimer = 0;
    short localTimer = 0;
    bool flagTime;
    
    chan scheduler_to_proc = [0] of {mtype:process}
    chan proc_to_scheduler = [0] of {mtype:process}
    
	proctype Sensor()	{
	do
	::scheduler_to_proc ? procS;
	  atomic {
	  if
		::(true) -> sensor = on;
		::(true) -> sensor = off; 
	    fi;
	  }
	  proc_to_scheduler ! procS;
	od; }
	
	proctype Drying() {
	do
	::scheduler_to_proc ? procDr;
	atomic{
		if
		  ::(prosState == pOff )->
			if 
			::(sensor == off) -> dryer = off;	             
			::else ->  {localTimer = 0; 
					   dryer = on;
					   prosState = pOn;}
			fi;
		  ::else ->
		    if
			::(sensor == on)-> localTimer = 0; 
			::(localTimer == 10) -> {localTimer = 0;  
			                         prosState = pOff ;
		  		                     dryer = off;
		  		                              	}	   
		    ::else -> skip;	     
		    fi;                                           
		  fi;
		 localTimer++; 
		proc_to_scheduler ! procDr;
	}
	od; }

	
    proctype Scheduler() {
    short thisTime = 0;
	do
	::	short i;
		for (i : 1..processCount) {
			mtype:process nextProc = activeProcesses[i-1];
		if 
		:: (nextProc != 0) ->
			scheduler_to_proc ! nextProc;
			proc_to_scheduler ? nextProc;
		:: else -> skip;
		fi;
	   }
	   
	    if
	    ::(thisTime == 0) -> flagTime = false; 
	                        if
	                        ::(sensor == on) -> thisTime = globalTimer + 5;
	                        ::else -> skip;
	                        fi; 
	    ::else -> if 
	              ::(globalTimer >= thisTime) -> thisTime = 0;
	              ::else ->  flagTime = true; 
	                         /* if 
	                          ::(sensor == on) -> thisTime++;
	                          ::else -> skip;
	                          fi; */
	                        
	              fi;        
	    fi;   
	    globalTimer++;
    od
    }
	
	init {
	  sensor = off;
	  prosState = pOff ;
	  dryer = off;
	  flagTime = false;
	  run Sensor();
	  activeProcesses[0] = procS;
	  run Drying(); 
	  activeProcesses[1] = procDr;
	  run Scheduler();
	  	}
     ltl f1 {[]((handOn) -> (<>(dryerOn&&flagT)))}