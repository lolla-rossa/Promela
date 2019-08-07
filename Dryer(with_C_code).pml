	#define handOn sensor == on
    #define dryerOn dryer == on
    #define handOff sensor == off
    #define dryerOff dryer == off
    #define flagT flagTime == true
  
   /* #define nTime localTime == 10*/
	
	c_code{unsigned long globalTimer = 0;
    unsigned long localTimer = 0;
    unsigned long  thisTime = 0;};

	mtype: procState = {pOn, pOff, pStop, pError};
	mtype: dryerState = {on, off};
	
	mtype:dryerState sensor;
	mtype:dryerState dryer;
	mtype:procState prosState;
	
	int processCount = 2;
	mtype:process = {procDr, procS};
	mtype:process activeProcesses[processCount];
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
			::(sensor == on) ->  c_code { localTimer = 0;}; 
					             dryer = on;
					             prosState = pOn;
			::(sensor == off) -> dryer = off;
			fi;
		  ::else ->
		    if
			::(sensor == on)-> c_code { localTimer = 0; };
			::(c_expr {localTimer == 10}) -> { c_code { localTimer = 0; }; 
			                                 prosState = pOff ;
				                             dryer = off;	};
			::else -> skip;
			fi;	                             	                    
		  fi;
		 c_code {
		 localTimer++; 
		};
		proc_to_scheduler ! procDr;
	}
	od; }
		
    proctype Scheduler() {
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
	    ::(c_expr {thisTime == 0}) ->  { flagTime = false; 
				                        if
				                        ::(sensor == on) -> c_code {thisTime = globalTimer + 5;};
				                        ::else -> skip;
				                        fi; }
	    ::else -> if 
	              ::c_expr {globalTimer >= thisTime} -> c_code {thisTime = 0;};
	              ::else ->  flagTime = true; 
	                          /*if 
	                          ::(sensor == on) -> c_code {thisTime++;};
	                          ::else -> skip;
	                          fi; */
	                        
	              fi;        
	    fi; 
	  c_code { globalTimer++;};
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
