package main

import (
	"bytes"
	"encoding/gob"
	"fmt"
	"log"
	"os"
	"sort"
	"strconv"
	"time"

	"github.com/hashicorp/nomad/api"
	"github.com/hashicorp/nomad/nomad/structs"
	"os/exec"
)

const (
	// pollInterval is how often the status command will poll for results.
	pollInterval = 5 * time.Second

	maxWait = 10 * time.Minute

	// blockedEvalTries is how many times we will wait for a blocked eval to
	// complete before moving on.
	blockedEvalTries = 3

	// pendingAllocTries is how many times we will wait for a pending alloc to
	// complete before moving on.
	pendingAllocTries = 3

	executors = 2
)

var numJobs, totalProcs int
var sparkHome, baseId, argsFile string

func main() {
	// Log everything to stderr so the runner can pipe it through
	log.SetOutput(os.Stderr)

	// Check the args
	if len(os.Args) != 2 {
		log.Fatalln(usage)
	}

	// Get the base id to use
	if sparkHome = os.Getenv("SPARK_HOME"); sparkHome == "" {
		log.Fatalln("[ERR] spark: SPARK_HOME must be provided")
	}

	// Get the base id to use
	if baseId = os.Getenv("BASE_ID"); baseId == "" {
		log.Fatalln("[ERR] spark: BASE_ID must be provided")
	}

	// Get the number of jobs to submit
	var err error
	v := os.Getenv("JOBS")
	if numJobs, err = strconv.Atoi(v); err != nil {
		log.Fatalln("[ERR] spark: JOBS must be numeric")
	}

	// Get the location of the job file
	if argsFile = os.Getenv("ARGS_FILE"); argsFile == "" {
		log.Fatalln("[ERR] spark: ARGS_FILE must be provided")
	}

	// Switch on the command
	switch os.Args[1] {
	case "setup":
		os.Exit(handleSetup())
	case "run":
		os.Exit(handleRun())
	case "status":
		os.Exit(handleStatus())
	case "teardown":
		os.Exit(handleTeardown())
	default:
		log.Fatalf("unknown command: %q", os.Args[1])
	}
}

func handleSetup() int {
	// Garbage collect on Nomad to clear any evaluations left over from a previous benchmarking attempt
	client, err := api.NewClient(api.DefaultConfig())
	if err != nil {
		log.Fatalf("[ERR] nomad: failed creating nomad client: %v", err)
		return 1
	}
	// Iterate all of the jobs and stop them
	log.Printf("[DEBUG] nomad: deregistering benchmark jobs")
	jobs, _, err := client.Jobs().List(nil)
	if err != nil {
		log.Fatalf("[ERR] nomad: failed listing jobs: %v", err)
	}
	for _, job := range jobs {
		if _, _, err := client.Jobs().Deregister(job.ID, false, nil); err != nil {
			log.Fatalf("[ERR] nomad: failed deregistering job: %v", err)
		}
	}
	// Trigger garbage collection
	if err := client.System().GarbageCollect(); err != nil {
		log.Fatalf("[ERR] nomad: error wihle garbage collecting: %v", err)
		return 1
	}
	return 0
}

func handleRun() int {

	jobSubmitters := 1 // 64
	if numJobs < jobSubmitters {
		jobSubmitters = numJobs
	}
	log.Printf("[DEBUG] nomad: using %d parallel submitters to submit %d applications", jobSubmitters, numJobs)

	// Submit the job the requested number of times
	doneCh := make(chan struct{})
	stopCh := make(chan struct{})
	defer close(stopCh)
	for i := 0; i < jobSubmitters; i++ {
		go submitJobs(numJobs, doneCh, stopCh)
	}
	for i := 0; i < jobSubmitters; i++ {
		select {
		case <-doneCh:
		}
	}
	return 0
}

func submitJobs(count int, doneCh chan <- struct{}, stopCh <-chan struct{}) {
	submitter := exec.Command(
		"java",
		"-classpath", sparkHome + "/assembly/target/scala-2.11/jars/*:tests/spark/submitter/target/scala-2.11/classes",
		"com.hashicorp.spark.submitter.SparkSubmitter",
		argsFile,
		baseId,
		strconv.Itoa(count))
	if out, err := submitter.CombinedOutput(); err != nil {
		log.Fatalf("[ERR] Error running SparkSubmitter: %v\nOutput: %s", err, string(out))
	}
	localDoneCh := make(chan struct{})
	go func() {
		submitter.Wait()
		close(localDoneCh)
	}()
	select {
	case <-localDoneCh:
	case <-stopCh:
		submitter.Process.Kill()
	}
	doneCh <- struct{}{}
}

func handleStatus() int {

	notYetSeen := make(map[string]struct{}, numJobs)
	running := make(map[string]struct{}, numJobs)
	seenTimes := make(map[string]int64, numJobs)
	doneTimes := make(map[string]int64, numJobs)

	// Determine the set of jobs we should track.
	log.Printf("[DEBUG] nomad: expecting %d jobs", numJobs)
	for i := 0; i < numJobs; i++ {
		// Increment the job ID
		notYetSeen[fmt.Sprintf("%s-%d", baseId, i)] = struct{}{}
	}

	// Get the API client
	client, err := api.NewClient(api.DefaultConfig())
	if err != nil {
		log.Fatalf("[ERR] nomad: failed creating nomad client: %v", err)
	}
	jobsEndpoint := client.Jobs()

	// Set up the args
	args := &api.QueryOptions{
		AllowStale: true,
	}

	// Wait for all the jobs to be complete.
	cutoff := time.Now().Add(maxWait)

	for {
		waitTime, exceeded := getSleepTime(cutoff)
		if !exceeded {
			log.Printf("[DEBUG] nomad: next eval poll in %s", waitTime)
			time.Sleep(waitTime)
		}

		// Start the query
		log.Printf("[DEBUG] nomad: listing jobs")
		resp, _, err := jobsEndpoint.List(args)
		log.Printf("[DEBUG] nomad: done listing jobs")
		if err != nil {
			// Only log and continue to skip minor errors
			log.Printf("[ERR] nomad: failed querying jobs: %v", err)
			continue
		}

		now := time.Now().Unix()

		for _, job := range resp {
			// Update job status
			if _, ok := notYetSeen[job.ID]; ok {
				delete(notYetSeen, job.ID)
				seenTimes[job.ID] = now
				running[job.ID] = struct{}{}
			} else if _, ok := running[job.ID]; !ok {
				continue
			}
			switch job.Status {
			case "pending":
			case "running":
			default:
				log.Printf("Done tracking %s as it now has status %s", job.ID, job.Status)
				doneTimes[job.ID] = now
				delete(running, job.ID)
			}
		}

		// Wait til all evals have gone through the scheduler.
		numNotYetSeen := len(notYetSeen)
		numRunning := len(running)
		if numNotYetSeen == 0 && numRunning == 0 {
			break
		} else {
			log.Printf("[DEBUG] nomad: expect %d finished jobs, still waiting to see %d and %d still running, polling again",
				numJobs, numNotYetSeen, numRunning)
		}
	}

	//// We now have all the evals, gather the allocations and placement times.
	//
	//// scheduleTime is a map of alloc ID to map of desired status and time.
	//scheduleTimes := make(map[string]map[string]int64, totalAllocs)
	//startTimes := make(map[string]int64, totalAllocs)    // When a task was started
	//receivedTimes := make(map[string]int64, totalAllocs) // When a task was received by the client
	//failedAllocs := make(map[string]int64)               // Time an alloc failed
	//failedReason := make(map[string]string)              // Reason an alloc failed
	//pendingAllocs := make(map[string]int)                // Counts how many time the alloc was in pending state
	//first := true
	//ALLOC_POLL:
	//for {
	//	waitTime, exceeded := getSleepTime(cutoff)
	//	if !exceeded && !first {
	//		log.Printf("[DEBUG] nomad: next eval poll in %s", waitTime)
	//		time.Sleep(waitTime)
	//	}
	//	first = false
	//
	//	needPoll := false
	//	for evalID := range evals {
	//		// Start the query
	//		resp, _, err := evalEndpoint.Allocations(evalID, args)
	//		if err != nil {
	//			// Only log and continue to skip minor errors
	//			log.Printf("[ERR] nomad: failed querying allocations: %v", err)
	//			continue
	//		}
	//
	//		for _, alloc := range resp {
	//			// Capture the schedule time.
	//			allocTimes, ok := scheduleTimes[alloc.ID]
	//			if !ok {
	//				allocTimes = make(map[string]int64, 3)
	//				scheduleTimes[alloc.ID] = allocTimes
	//			}
	//			allocTimes[alloc.DesiredStatus] = alloc.CreateTime
	//
	//			// Ensure that they have started or have failed.
	//			switch alloc.ClientStatus {
	//			case "failed":
	//				failedAllocs[alloc.ID] = alloc.CreateTime  // not ModifyTime or time of failure event?
	//				var failures []string
	//				for _, state := range alloc.TaskStates {
	//					if state.State == "failed" {
	//						failures = append(failures, state.Events[0].DriverError)
	//					}
	//				}
	//				failedReason[alloc.ID] = strings.Join(failures, ",")
	//				continue
	//			case "pending":
	//				pendingAllocs[alloc.ID]++
	//				tries := pendingAllocs[alloc.ID]
	//				if tries < pendingAllocTries {
	//					needPoll = true
	//				} else if tries == pendingAllocTries {
	//					log.Printf("[DEBUG] nomad: abandoning alloc %q", alloc.ID)
	//				}
	//				continue
	//			}
	//
	//			// Detect the start time.
	//			for _, state := range alloc.TaskStates {
	//				if len(state.Events) == 0 {
	//					needPoll = true
	//				}
	//
	//				for _, event := range state.Events {
	//					time := event.Time
	//					switch event.Type {
	//					case "Started":
	//						startTimes[alloc.ID] = time
	//					case "Received":
	//						receivedTimes[alloc.ID] = time
	//					}
	//				}
	//			}
	//		}
	//	}
	//
	//	if needPoll && !exceeded {
	//		continue ALLOC_POLL
	//	}
	//
	//	break
	//}
	//
	//// Print the failure reasons for client allocs.
	//for id, reason := range failedReason {
	//	log.Printf("[DEBUG] nomad: alloc id %q failed on client: %v", id, reason)
	//}
	//
	//// Print the results.
	//if l := len(failedEvals); l != 0 {
	//	fmt.Fprintf(os.Stdout, "failed_evals|%f\n", float64(l))
	//}
	for time, count := range accumTimes(seenTimes) {
		fmt.Fprintf(os.Stdout, "seen_jobs|%f|%d\n", float64(count), time)
	}
	for time, count := range accumTimes(doneTimes) {
		fmt.Fprintf(os.Stdout, "done_jobs|%f|%d\n", float64(count), time)
	}
	//for time, count := range accumTimes(receivedTimes) {
	//	fmt.Fprintf(os.Stdout, "received|%f|%d\n", float64(count), time)
	//}
	//for time, count := range accumTimesOn("run", scheduleTimes) {
	//	fmt.Fprintf(os.Stdout, "placed_run|%f|%d\n", float64(count), time)
	//}
	//for time, count := range accumTimesOn("failed", scheduleTimes) {
	//	fmt.Fprintf(os.Stdout, "placed_failed|%f|%d\n", float64(count), time)
	//}
	//for time, count := range accumTimesOn("stop", scheduleTimes) {
	//	fmt.Fprintf(os.Stdout, "placed_stop|%f|%d\n", float64(count), time)
	//}
	//
	//// Aggregate eval triggerbys.
	//triggers := make(map[string]int, len(evals))
	//for _, eval := range evals {
	//	triggers[eval.TriggeredBy]++
	//}
	//for trigger, count := range triggers {
	//	fmt.Fprintf(os.Stdout, "trigger:%s|%f\n", trigger, float64(count))
	//}
	//
	//// Print if the scheduler changed scheduling decisions
	//flips := make(map[string]map[string]int64) // alloc id -> map[flipType]time
	//flipTypes := make(map[string]struct{})
	//for id, decisions := range scheduleTimes {
	//	if len(decisions) < 2 {
	//		continue
	//	}
	//	// Have decision -> time
	//	// 1) time -> decision
	//	// 2) sort times
	//	// 3) print transitions
	//	flips[id] = make(map[string]int64)
	//	inverted := make(map[int64]string, len(decisions))
	//	times := make([]int, 0, len(decisions))
	//	for k, v := range decisions {
	//		inverted[v] = k
	//		times = append(times, int(v))
	//	}
	//	sort.Ints(times)
	//	for i := 1; i < len(times); i++ {
	//		from := decisions[inverted[int64(times[i - 1])]]
	//		to := decisions[inverted[int64(times[i])]]
	//		flipType := fmt.Sprintf("%s-to-%s", from, to)
	//		flips[id][flipType] = int64(times[i])
	//		flipTypes[flipType] = struct{}{}
	//	}
	//}
	//
	//for flipType, _ := range flips {
	//	for time, count := range accumTimesOn(flipType, flips) {
	//		fmt.Fprintf(os.Stdout, "%v|%f|%d\n", flipType, float64(count), time)
	//	}
	//}

	return 0
}

// getSleepTime takes a cutoff time and returns how long you should sleep
// between polls and whether you have exceeded the cutoff.
func getSleepTime(cutoff time.Time) (time.Duration, bool) {
	now := time.Now()
	if now.After(cutoff) {
		return time.Duration(0), true
	}

	desiredEnd := now.Add(pollInterval)
	if desiredEnd.After(cutoff) {
		return cutoff.Sub(now), false
	}

	return pollInterval, false
}

// accumTimes returns a mapping of time to cumulative counts. Takes a map
// of ID's to timestamps (ID is unimportant), and returns a mapping of
// timestamps to the cumulative count of events from that time.
// Ex: {foo: 10, bar: 10, baz: 20} -> {10: 2, 20: 3}
func accumTimes(in map[string]int64) map[int64]int64 {
	// Initialize the result.
	out := make(map[int64]int64)

	// Hot path if we have no times.
	if len(in) == 0 {
		return out
	}

	// Convert to intermediate format to handle counting multiple events
	// from the same timestamp.
	intermediate := make(map[int64]int64)
	for _, v := range in {
		intermediate[v] += 1
	}

	// Create a slice of times so we can sort it.
	var times []int64
	for time := range intermediate {
		times = append(times, time)
	}
	sort.Sort(Int64Sort(times))

	// Go over the times and populate the counts for each in the result.
	out[times[0]] = intermediate[times[0]]
	for i := 1; i < len(times); i++ {
		out[times[i]] = out[times[i - 1]] + intermediate[times[i]]
	}

	return out
}

func accumTimesOn(innerKey string, in map[string]map[string]int64) map[int64]int64 {
	converted := make(map[string]int64)
	for outerKey, data := range in {
		for k, v := range data {
			if k == innerKey {
				converted[outerKey] = v
			}
		}
	}
	return accumTimes(converted)
}

func handleTeardown() int {
	// Get the API client
	client, err := api.NewClient(api.DefaultConfig())
	if err != nil {
		log.Fatalf("[ERR] nomad: failed creating nomad client: %v", err)
	}

	//// Iterate all of the jobs and stop them
	//log.Printf("[DEBUG] nomad: deregistering benchmark jobs")
	//jobs, _, err := client.Jobs().List(nil)
	//if err != nil {
	//	log.Fatalf("[ERR] nomad: failed listing jobs: %v", err)
	//}
	//for _, job := range jobs {
	//	if _, _, err := client.Jobs().Deregister(job.ID, false, nil); err != nil {
	//		log.Fatalf("[ERR] nomad: failed deregistering job: %v", err)
	//	}
	//}
	return 0
}

func convertStructJob(in *structs.Job) (*api.Job, error) {
	gob.Register([]map[string]interface{}{})
	gob.Register([]interface{}{})
	var apiJob *api.Job
	buf := new(bytes.Buffer)
	if err := gob.NewEncoder(buf).Encode(in); err != nil {
		return nil, err
	}
	if err := gob.NewDecoder(buf).Decode(&apiJob); err != nil {
		return nil, err
	}
	return apiJob, nil
}

// Int64Sort is used to sort slices of int64 numbers
type Int64Sort []int64

func (s Int64Sort) Len() int {
	return len(s)
}

func (s Int64Sort) Less(a, b int) bool {
	return s[a] < s[b]
}

func (s Int64Sort) Swap(a, b int) {
	s[a], s[b] = s[b], s[a]
}

const usage = `
NOTICE: This is a benchmark implementation binary and is not intended to be
run directly. The full path to this binary should be passed to bench-runner.

This benchmark measures the time taken to schedule and begin running tasks
using Nomad by HashiCorp.

To run this benchmark:

  1. Create a job file for Nomad to execute.
  2. Run the benchmark runner utility, passing this executable as the first
     argument. The following environment variables must be set:

       JOBSPEC - The path to a valid job definition file
       JOBS    - The number of times to submit the job

     An example use would look like this:

       $ JOBSPEC=./job1.nomad JOBS=100 bench-runner bench-nomad
`
