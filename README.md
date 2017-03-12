# Work in progress disclaimer
At this time, this software is not in it's *"Release"* state. There is unused code in the source, code that misbehaves, and known glitches. Progress will now be submitted here and will be visible in the Commits section as I'm actively working on it when I get the time. Right now, the software compiles but it's not guaranteed to run correctly because it's in a state of transition. I began replacing procedural code that's CPU bound with Object Oriented Code and didn't finish it, there may be bits that misbehave left and there are incomplete utility classes. You are free to tamper with it though.

# Crusader
Crusader is a personal project I started for a small community and because I had interest in parallel processing. It's nothing wow, it's bruting hashes made with **Jenkins 32bit** hashing algorithm, on the GPU, more specific, a **CUDA GPU**. There is still much more to explore, the initial challenge was to transpose a procedural algorithm in a parallel algorithm, while getting rid of all char variables (**CUDA** cores don't know chars) and mantaining speed, the second challenge came from distributing the work efficiently.

# How it's working
You have to give each thread the task to hash a word and check if it matches, doing this on the cpu is not efficient, I had to come up with something else, also, doing a loop in each thread breaks paralellism too, since the last thread will have to run the previous thread word generation + 1. So I took the algorithm you use on paper to do sum and applied it, the cpu generates a new word adding the total number of threads for each cycles. Now each thread does the same using it's unique thread id, yes, there is still a difference between first and last thread but now it's more negligeable, I'll have to run more tests, maybe breaking the task into smaller cycles of kernel runs may help in the long run.

After the generating and the hashing, each thread compares it's hash to the list of input hashes, I'm aware this is not so efficient and is a critical area to improve, I believe by processing the input hash list I can cut more corners.

# How to build
You need to have CUDA Toolkit installed, I developed this using CUDA 7.5 and it is not tested with newer versions (like 8.0). It's also developed using Visual Studio 2013 because the version of Nsight coming with 7.5 wasn't pairing well with 2015 either. Right now, vs2015 is officially supported in CUDA Toolkit 8.0.

Apart from that everything should be set, including custom post-build events.

# TO DO features - in order of priority:
- **Multi-threading:** I ran a dev build with multithreading and there were some inconsistencies, but it's definitely coming, while bruting works there is some overhead on the CPU;
- **Benchmark tool:** User will be able to run this and find out the differences both in seconds and in percents between CPU run and multiple different configurations for GPU;
- **Auto-load balancing:** Will make use of some logic from the benchmark tool to automatically find the optimum parameters for bruting, it will be toggle-able from the config;
- **SLi support:** Do-able but it will have to wait for multi-threading to be a stable thing.


# The commenting
You may notice the code is heavily commented and in some places unnecessary for anyone with decent knowledge of programming / c. I wanted for everyone to be able to read and understand what each line does, it may spark interest for parallelism in others, I personally like explicit materials in new areas I dwelve into and I'm giving back albeit I'm no expert. So if they are no use for you please don't mind them, I hope someone will make use of them.
