type Idx: record {
	i: int;
};

type Sval: record {
	t: time;
};

type Val: record {
	b: bool;
	c: count;
	p: port;
	sn: subnet;
	a: addr;
	d: double;
	t: time;
	iv: interval;
	s: string;
	sc: set[count];
	ss: set[string];
	se: set[string];
	vc: vector of int;
	ve: vector of int;
};


#@load frameworks/communication/listen

redef pkt_profile_file = open_log_file("pkt-prof");
redef pkt_profile_mode = PKT_PROFILE_MODE_SECS;
redef pkt_profile_freq = 1.0;

## Configuration option: factor with which the current lines-per-second rate is multiplied each hartbeat interval
## default: 1 -> to not grow.
#redef InputBenchmark::factor = 1.5;

## Configuration option: usleep interval that is inserted between each line. Can be used to spread out the events over the heartbeat interval.
## User must take care to keep this small enough that all lines are queued within heartbeat-interval, otherwise heartbeats will start queueing up.
## default: 0 -> disabled. Must be < 1000000 ( 1 sec ), otherwise implementations might ignore it.
#redef InputBenchmark::spread = 1;

## Configuration option: factor which is added to the current lines-per-second rate each heartbeat interfal
## default 0 -> don't add anything
#redef InputBenchmark::addfactor = 2000;

## Configuration option: same as spread, but dymanic.
## Auutospread sets the spreading interval based on the current number of lines per second:
## usleep ( 1000000 / autospread * num_lines )
## default 0.0 -> disabled.
#redef InputBenchmark::autospread = 2.5;

## Configuration option: timed spreads
## default: 0 -> disabled. Everything else - percentage of heartbeat interval that should not be used to send stuff.
## so -> 0.15 means that all data will be send in the first 85% of heartbeat_interval.
redef InputBenchmark::timedspread = 0.05;

redef Threading::heart_beat_interval = 5.0 secs;

global outfile: file;

global servers: table[int] of Val = table();
global firstbeat: bool;
global lastheartbeat: time;
global tries: count;

event line(description: Input::EventDescription, tpe: Input::Event, t: time) {
	# do nothing.
}

event linecomplex(description: Input::EventDescription, tpe: Input::Event, v: Val) {
	# print v;
}

event bro_init()
{
	outfile = open ("timings.log");
	# first read in the old stuff into the table...
## Configuration option:
## $source specifies the initial number of lines per minute that are generated by the benchmark reader.
## choose either tables or events - tables are way more expensive.

	# complicated table
	Input::add_table([$source="4000", $name="ssh", $idx=Idx, $val=Val, $destination=servers, $reader=Input::READER_BENCHMARK, $mode=Input::REREAD]);

	# simple table
	#Input::add_table([$source="150000", $name="ssh", $idx=Idx, $val=Sval, $destination=servers, $reader=Input::READER_BENCHMARK, $mode=Input::REREAD]);

	# simple event
	#Input::add_event([$source="1", $name="input", $fields=Sval, $ev=line, $reader=Input::READER_BENCHMARK, $mode=Input::STREAM]);
	
	# complicated event
	#Input::add_event([$source="10000", $name="input", $fields=Val, $ev=linecomplex, $reader=Input::READER_BENCHMARK, $mode=Input::STREAM, $want_record=T]);
	print outfile, "ts lines";

	lastheartbeat = current_time();
	firstbeat = T;
	tries = 0;
}


## event is raised every time, an heartbeat is completed by the benchmark reader.
event HeartbeatDone() {
	local difference = (current_time() - lastheartbeat);
	print fmt("last heartbeat Current time: %f", current_time());

	firstbeat = F;
	lastheartbeat = current_time();

	#tries = tries + 1;
	#
	#if ( tries == 4 ) {
	#	print |servers|;
	#	close(outfile);
	#	terminate();
	#}
}

## this event is raised if InputBenchmark::factor is != 1.0 each time the number of lines per seconds is changed.
event lines_changed(newlines: count, changetime: time) {
	print outfile,(fmt("%f %d", changetime, newlines));
	print fmt("Rate changed to %d lines per second at %f", newlines, changetime);
}

