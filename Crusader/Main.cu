#ifndef __CUDA_RUNTIME_H__
#include "cuda_runtime.h"                               // This is needed for CUDA calls
#endif

#ifndef __DEVICE_LAUNCH_PARAMETERS_H__
#include "device_launch_parameters.h"				    // Again, needed for CUDA calls, don't touch
#endif 

#ifndef _FSTREAM_
#include <fstream>										// Fstream for filehandling, loading, saving, providing settings etc.
#endif

#ifndef _IOSTREAM_
#include <iostream>										// Crusader prints data periodic in the console, I like to use iostreams instead of print functions, also I use hex calls from streams
#endif

#ifndef _INC_TIME
#include <time.h>										// This is intended to be used for benchmark, currently it's use is minimal and not quite fair
#endif 

#ifndef _SSTREAM_
#include <sstream>										// I like working with chars, but sometimes I just need the job done, this is used in the PropertyManager classes
#endif

/* LEGACY_CODE 
#ifndef _STRING_
#include <string>										
#endif
*/

#ifndef _INC_CONIO
#include <conio.h>										// The 'ol conio, I use this to keep console up before closing
#endif

#ifndef PROPERTY_MANAGER_H
#include "PropertyManager/PropertyManager.h"			/* Custom class I created to handle property reading, setting etc. Although initially I didn't mean to
														use classes or cpp in this CUDA project I wanted cleaner main and wanted to do it in a clean OOP manner.*/
														
#endif


// All the values (except THREADSCOUNT) here are further passed to PropertyManager class which edits them according to config.cfg if this exists, otherwise it defaults to these values.
int MAX_WORD_SIZE = 10,									// This specific variable tells Crusader at what word length it should stop, after bruting it
	WORD_BUFFER_SIZE = MAX_WORD_SIZE + 1,				// We set up a word buffer, the reason for the +1 is I sometimes like to keep the first position empty in case I need auxiliary values passed together
	BLOCKS = 256,										// Number of Blocks the CUDA environment should run / cycle
	THREADS = 1024,										// Number of Threads each CUDA block has / cycle
	THREADSCOUNT = BLOCKS*THREADS,						// This variable is just for internal purposes and is not exposed in the config, it's use will become obvious further in the program
	SAVE_CYCLES_COUNT = 250;							/* This is the number of cycles before the saving kicks in, problem with this is cycles completion speed varies depending on GPU power,
															and BLOCKS & THREADS setting, so this need to be replaced soon with a timer*/

/*LEGACY_CODE
unsigned int alphabet_values[39] = {
        '\0', 'a', 'b', 'c', 'd', 'e', 'f', 'g','h', 'i',
        'j', 'k', 'l', 'm', 'n', 'o', 'p', 'q', 'r', 't',
        's', 'u', 'v', 'w', 'x', 'y', 'z', '-','_','0','1',
        '2','3','4','5','6','7','8','9'
    };*/

unsigned int *alphabet_values;				// We set up a pointer which will later become the first adress of our alphabet values array, values number is not specified so this needs to be dynamic

unsigned int word_len_start_size = 1;		// The size from which Crusader starts bruting, this is the default, but it is changed when a file is loaded if it's the case
unsigned int input_hash_count = 1;			// This is used mainly as an iterator starting from 1 for the hashes that are read dynamic
int alphabet_size;							// A value that should store the alphabet size which usually is number_of_characters_in_input_file + 1 for a dead character I need for this algorithm which is on position 0


inline cudaError_t CudaBrute(
        unsigned int *return_array,
        unsigned int *stop_flag_end_of_bruting,
        unsigned int *last_bruted_word_size,
        unsigned int *new_word_seed,
        unsigned int *found_matching_hashes_array,
        const unsigned int *input_hash_list_to_match
);

__global__ void protoBruteKernel(
        unsigned int *return_array,
        const unsigned int *seed_word,
        const unsigned int *alphabet,
        const int alphabetSize,
        unsigned int *stop,
        const unsigned int word_len_start_size,
        unsigned int *last_bruted_word_size,
        unsigned int *new_word_seed,
        unsigned int *found_matching_hashes_array,
        const unsigned int *input_hash_list_to_match,
        const unsigned int word_buffer_size,
        const unsigned int max_word_size,
        const unsigned int threadscount
){



	//IMPORTANT: Although I may have missed this in some comments, from beginning until the ending of addition algorithm and transition to the hashing one, the value of the arrays we perform operations on, are actually positions withing a given alphabet, not actual char values.
    unsigned int *cuda_word = new unsigned int[word_buffer_size];                       //This will be the storage for the word assigned to this thread, it represents words as unsigned int arrays because CUDA (7.5) doesn't works well with chars in kernels
    int index = max_word_size;															//This holds the start index for the generation from seed, each Thread generates it's word from a seed specific to each batch + it's thread id
    unsigned int cuda_word_size = 1;													//????????
    unsigned int cuda_word_not_finished = 1;											//???????
    unsigned int thread_unique_index = blockDim.x * blockIdx.x + threadIdx.x;			//We grab the thread unique Id, in CUDA each thread gets an ID within its block starting from 0, because we are working in 1D, we do: blockDimension in X * blockId (each block has it's own id, and thread ids get reset between blocks) * threadLocalID
    unsigned int cuda_word_curr_letter = 0;												//?????
    unsigned int cuda_word_left_overs = thread_unique_index;							//this variable holds if there's anything left to add to the word, it is initialized with the thread unique id so it can generate the word from the seed
    for (int j = index; j >0; j--)
    {
        cuda_word[j] = seed_word[j];													//In this loop we fill our thread word array with the seed word given by the CPU
    }


    do                                                                                 //Here we start looping and doing the addition algorithm to generate the specific word we need to hash and check
    {
        cuda_word[index] += cuda_word_left_overs;										//Add on current position (remember it starts from the rightmost character) all the leftovers
        if (cuda_word[index] >= alphabetSize)											//Do the current position's value exceeds all possible input values (input alphabet size)?
        {
            cuda_word_curr_letter = cuda_word[index];	                                //Save in auxiliary variable our current position value
            cuda_word[index] = (cuda_word_curr_letter % (alphabetSize-1)) + 1;          //The new position value of this specific character will be the modulo of the current position value - 1 because we add afterwards 1 so basically shifting everything to right so we never get position 0 which is reserverd as "\0"
            cuda_word_left_overs = cuda_word_curr_letter / alphabetSize;                //The new leftovers become the div between our saved value and the number of elements in the given alphabet, basically this is digit addition
            
			if (cuda_word_left_overs > 0)												//If there are still left-overs, increase the current word size (we increase to the left)
            {
                cuda_word_size++;
            }
        }
        else                                                                           //If the current position value after adding the leftovers is within input values
        {
            cuda_word_left_overs = 0;													//We have no more leftovers
        }

        if (cuda_word_size >max_word_size || index == 1 || cuda_word_left_overs == 0)	//IF: the new generated word is bigger than the limit size set OR ??????? OR there are no left overs
        {
            cuda_word_not_finished = 0;													//We can say this is not true => We finished generation of word position values
        }

        index--;																		//Decrease the index, it will be relevant if the generation didn't end
    } while (cuda_word_not_finished); //Loop until we decide generation has finished

    if (cuda_word_size<word_len_start_size)                                            
    {
        cuda_word_size = word_len_start_size;
    }


    if (cuda_word_size>max_word_size)                                                   //Is the new generated word bigger than the set limit? If yes we need to signal the bruter should stop at the end of this batch
    {
        return_array[thread_unique_index] = 0;											//We return no value
        *last_bruted_word_size = cuda_word_size;										//?????????We pass the new length we hit !?

        for (int j = max_word_size; j >0; j--)
        {
            new_word_seed[j] = cuda_word[j];                                            //
        }
        *stop = 1;																		//This is the stop flag the CPU thread will look to at the end of each batch, we set this to true so it will know to stop
    }
    else                                                                                //If the word is ok, we can start hashing the word with the real values (values from position values within the alphabet)
    {
        found_matching_hashes_array[thread_unique_index] = 0;                           //We start by setting the return hash as 0 ???????

		//This is where the jenkins hashing algorithm begins, it's adapted to work on our array instead of number decimals
        for (int index = max_word_size - cuda_word_size + 1; index <= max_word_size; index++) //We loop starting from the last generated character (substracting from max size, the current size and advancing by 1)
        {
            if (cuda_word[index]!=0)                                                    //If it's not a 0 (since 0 can't be achieved within the addition algorithm and it's there only at generation, meaning 0 is null) proceess
            {
                found_matching_hashes_array[thread_unique_index] += alphabet[cuda_word[index]];
                found_matching_hashes_array[thread_unique_index] += found_matching_hashes_array[thread_unique_index] << 10;
                found_matching_hashes_array[thread_unique_index] ^= found_matching_hashes_array[thread_unique_index] >> 6;
            }
			else                                                                        //If we did hit a null (awkward?)
			{
                break;
            }
        }
        found_matching_hashes_array[thread_unique_index] += found_matching_hashes_array[thread_unique_index] << 3;
        found_matching_hashes_array[thread_unique_index] ^= found_matching_hashes_array[thread_unique_index] >> 11;
        found_matching_hashes_array[thread_unique_index] += found_matching_hashes_array[thread_unique_index] << 15;

        return_array[thread_unique_index*word_buffer_size] = 0;  //WAT?
    
        for (int index = 1; index <= input_hash_list_to_match[0];index++)
        {
            if (found_matching_hashes_array[thread_unique_index] == input_hash_list_to_match[index])
            {
                return_array[thread_unique_index*word_buffer_size] = cuda_word_size;
                for (int j = max_word_size - cuda_word_size + 1; j <= max_word_size; j++)
                {
                    return_array[j + thread_unique_index*word_buffer_size] = alphabet[cuda_word[j]];
                }
                
                break;
            }
        }
    }

    if (thread_unique_index == threadscount - 1) //Is this the last thread from the batch? If yes:
    {
        *last_bruted_word_size = cuda_word_size;  //The size this thread got to will be transmited to the CPU Thread size count so it knows the new word size
        for (int j = max_word_size - cuda_word_size + 1; j <= max_word_size; j++)
        {
            new_word_seed[j] = cuda_word[j];     //Loop and copy this word position values to the new seed for the CPU
        }
    }
    delete[] cuda_word;                         //Memory free for the dynamic cuda_word, just in case
}
//512 with 1024

int main()
{
	/* We pass variables to the PropertyManager
	TO-DO:
	- Currently syntax in function declaration uses & to retrieve variables by reference, change this behaviour to explicitely send &var adresses from the call so it's easier to read here
	- Initially it was intended to have a Macro that transforms variable names in strings and internally names them in PropertyManager, this needs to be adressed for cleaner, more savvy code
	*/
    PropertyManager::registerProperty("MAX_WORD_SIZE", MAX_WORD_SIZE);
    PropertyManager::registerProperty("BLOCKS", BLOCKS);
    PropertyManager::registerProperty("THREADS", THREADS);
	PropertyManager::registerProperty("SAVE_CYCLES_COUNT", SAVE_CYCLES_COUNT);
   // PropertyManager::parse();					// The parse function actually starts the .cfg reading, until then nothing happens, because of this design, it's possible to implement .cfg hotswap

    WORD_BUFFER_SIZE = MAX_WORD_SIZE + 1;		// Since we read from config we need to update the buffer_size, if hotswap is to be implemented, this needs to go in parse(), maybe have a registerRelation() function
    THREADSCOUNT = BLOCKS*THREADS;				// Same as buffer
	

    std::ifstream save_file_fail_safe("savefile.mace");								// We declare the input savefile name and extension
    std::ifstream input_hashes_file("hashes.txt");									// This is the file from where the hashes are read
    unsigned int file_input_buffer = 0;												// We create a variable (buffer) to help us read, and we make sure it's empty
    unsigned int cpu_last_bruted_word_size = 1;										/* This variable needs to know what last seed the CPU generated,
																					 seed is needed because CUDA should not modify input array => After a cycle, CPU needs to calculate the next seed alone by jumping by THREADSCOUNT units*/
	unsigned int *input_hash_list_to_match;											// This is the start adress pointer of the array which will hold all the hashes read from file
    //LEGACY CODE unsigned int *cpu_word_seed = new unsigned int[WORD_BUFFER_SIZE];				// We create an array big enough so the CPU can generate until the last seed needed
    unsigned int *cuda_results = new unsigned int[THREADSCOUNT*WORD_BUFFER_SIZE];	// This is the array in which the results come from CUDA, it's size is determined by formula: For each thread run by CUDA it needs to have the full buffer size
    unsigned int *stop_flag_end_of_bruting = new unsigned int[1];					// Simple variable I use to tell the CPU algorithm to stop starting cycles since CUDA finished the wordsize in it's threads
    unsigned int *last_bruted_word_size = new unsigned int[1];						// In this variable we read values from the GPU, if the GPU value is bigger than the current value of variable it means the Threads finished a word size and moved onto the next
    unsigned int *new_word_seed = new unsigned int[WORD_BUFFER_SIZE];				/////////// WTF!?
    unsigned int *found_matching_hashes_array = new unsigned int[THREADSCOUNT];
    int index = 0;
    int days, hours, minutes, seconds;
    int completed_cuda_cycles_count = 0;


	try {																				//Just a usual handling of input/output with a try and catch statement
		std::ifstream alphabet_file_input("alphabet.txt");								// Declaring the alphabet input file which currently is handled with the static naming
		if (alphabet_file_input.good()) {												// Alphabet file exists and is not in use?
			std::string alphabet_buffer;												// We need a variable to read from file
			std::getline(alphabet_file_input, alphabet_buffer);							// Read the alphabet file into the buffer

			alphabet_size = alphabet_buffer.length()+1;									/* Because of the way the algorithm in cuda kernel currently works,
																						 we need to have a null value on 1st element (position 0) of the alphabet array*/

			// LEGACY_CODE alphabet_values = new unsigned int[alphabet_size+1];		 
			alphabet_values = new unsigned int[alphabet_size];						    // Declare the alphabet array values with the modified size from before. 

			for (int index = 1;index <= alphabet_buffer.length();index++)
			{
				alphabet_values[index] = (int)alphabet_buffer[index-1];					// Copy each char/int into the array values, there's a typecast to ensure data type
			}
			alphabet_values[0] = (int)'\0';												// This is the null on 0 position I commented above, needed for th

		}
		else                                                                           
		{
			/*If the alphabet file is either in use or doesn't exist, we throw with an int,
			/ not the most beautiful throw statement but it does the job*/

			// LEGACY_CODE std::cout << "Alphabet could not be loaded, check if file 'alphabet.txt' exists or is not in use.";
			throw 0;
		}
	}
	catch (int e)											
	{

		/* If the try/catch threw, we need to stop, although it is a try/catch and it's first purpose is to avoid crashing,
		currently Crusader doesn't handle a missing alphabet although it's easily fixable*/

		std::cout << "Alphabet could not be loaded, check if file 'alphabet.txt' exists or is not in use. Crusader needs to be re-opened."; // Print something for the user
		_getch(); // Make sure console stays there for the user to read the print
		return 0; // Exit the program (this return is in main)
	}

    if (save_file_fail_safe.good())
    {
		
        std::cout << "Savefile detected, loaded progress!\n";
		unsigned int buffer;
		/*std::cout << "Loaded word: ";
		save_file_fail_safe >> word_len_start_size;
        for (index = 1; index <= word_len_start_size; index++)
        {
            save_file_fail_safe >> file_input_buffer;
            new_word_seed [MAX_WORD_SIZE - word_len_start_size + index] = file_input_buffer;
            std::cout << (char)alphabet_values[file_input_buffer];
        }
        std::cout << " with size " << word_len_start_size<<"\n";*/
		save_file_fail_safe >> buffer;
		if (buffer == 1)
		{
			std::cout << "This savefile is from a finished bruting, Crusader will start from scratch.\n";
			for (index = MAX_WORD_SIZE; index >= 0; index--)
			{
				*(new_word_seed + index) = 0;
			}
			*(new_word_seed + MAX_WORD_SIZE) = 1;
		}
		else
		{
			int alphabet_start = save_file_fail_safe.tellg();
			char alphabet_difference = 0;
			std::string alphabet_test;
			save_file_fail_safe >> alphabet_test;
			for (int i = 1; i <= alphabet_size; i++)
			{
				if (alphabet_test.at(i-1) != (char)alphabet_values[i])
				{
					alphabet_difference = 1;
				}
			}
			if (alphabet_difference == 1)
			{
				"Alphabet discrepancy detected. Alphabet used for savefile is different than current alphabet. While this is not a big problem and bruting could continue after safety checks, because at this momment there is no direct interaction with these systems Crusader will not continue until current alphabet is changed to match savefile or savefile is deleted. NOTE: Please do not manually alter the alphabet in savefile until the new alphabet is same size or bigger than previous, also this is not recommended because you are skipping new results by doing that, until you know exactly what you are doing.";
				_getch();
				return 0;
			}









			//THERE IS SOMETHING MISSING HERE - NEED TO FIX.
			/*else
			{
				save_file_fail_safe >> buffer;
				if (buffer
			}*/
			
		}
    }
    else              //This happens if the fail is not available, either being missing either it's in use
    {
        std::cout<<"Savefile could not be found or is in use, starting from scratch\n";        //Let the user know
        for (index = MAX_WORD_SIZE; index >= 0; index--)                                       //Since we start from scratch we initialize everything with 0 -the null value, not first element- with the size of the max of current config.
        {
            *(new_word_seed + index) = 0;
        }
        *(new_word_seed + MAX_WORD_SIZE) = 1;													//We let last character to be first index of the alphabet because Threads start from 0 and we use their indexes for generation
    }
    save_file_fail_safe.close();                                                               //We don't need the input save fail anymore

    if (input_hashes_file.good()){																//Does the input hashes list exists or is not in use?

		unsigned int counter = 0;																//Need to keep track how many of these we have
		while (input_hashes_file >> std::hex >> file_input_buffer)								//Count ever one of them
		{
			counter++;
		}


		input_hash_list_to_match = new unsigned int[counter+1];                                 //Allocate new memory with the size of the input list
		input_hashes_file.clear();																//We clear any operation remnants we did on the file
		input_hashes_file.seekg(0, std::ios::beg);                                              //We position ourselves at the start
        while (input_hashes_file >> std::hex >> file_input_buffer)								//Begin reading the hashes in the new list
        {
            input_hash_list_to_match[input_hash_count] = file_input_buffer;
			input_hash_count++;
        }
        input_hash_list_to_match[0] = counter;
    }
    else
    {
        std::cout << "Input hash list (hashes.txt) not found, check if it's valid. Crusader will start anyway";
    }


    for (index = 0; index < THREADSCOUNT; index++)			//We iterate on the array of results of each Cycle (which is determined by THREADSCOUNT aka THREADS*BLOCKS)
    {
        *(cuda_results + index) = 0;						//Set them to 0, 0 will be null, any other value returned will be a positive match and will be outputted
    }
    clock_t clockt_start_timestamp, clockt_end_timestamp;  //Init vars for time control
	clockt_start_timestamp = clock();                      // Start clockin'

    do{			//This is where a cycle begins
        cudaError_t cudaStatus = CudaBrute(cuda_results, stop_flag_end_of_bruting,last_bruted_word_size,new_word_seed,found_matching_hashes_array,input_hash_list_to_match); //We init a cudaError_t variable which is a cuda default type for errors and returned from kernels


        if (cudaStatus != cudaSuccess) {			//We check if the call failed
            fprintf(stderr, "CudaBrute failed!");
            return 1;
        }


        for (index = 0; index < THREADSCOUNT; index++)   //Begin the sweep for results
        {
            if (cuda_results[index*WORD_BUFFER_SIZE] != 0){  //Is there a result?
                std::ostringstream fileNameStream("");		//Create an empty outputstringstream to use as hex name fo the file
                fileNameStream << std::hex << found_matching_hashes_array[index] << ".txt"; //Concatenate the name for the target file
                std::ofstream output(fileNameStream.str(), std::ios::app);	//Open with append argument the file for which the hash is
                std::cout << "String found: ";
                for (int j = MAX_WORD_SIZE - cuda_results[index*WORD_BUFFER_SIZE]+1; j <= MAX_WORD_SIZE; j++)
                {
                    std::cout << (char)cuda_results[j + index*WORD_BUFFER_SIZE];
                    output << (char)cuda_results[j + index*WORD_BUFFER_SIZE];
                }
                std:: cout << "\n";
                output << "\n";
                output.close();
            }
        }
    
        cpu_last_bruted_word_size = word_len_start_size;
        word_len_start_size = *last_bruted_word_size;
        if (word_len_start_size != cpu_last_bruted_word_size){
    
            clockt_end_timestamp = clock();
            seconds = (float)(clockt_end_timestamp - clockt_start_timestamp) / CLOCKS_PER_SEC;
            minutes = seconds / 60;
            seconds %= 60;
            hours = minutes / 60;
            minutes %= 60;
            days = hours / 24;
            hours %= 24;

            std::cout << "Word size "<<cpu_last_bruted_word_size<< " finished in " << days<<"d "<<hours<<"h "<<minutes<<"m "<<seconds << "s\n"; clockt_start_timestamp = clock();
        }
        if (completed_cuda_cycles_count > SAVE_CYCLES_COUNT){
            std::ofstream output("savefile.mace");
            std::cout << "Saved new start point: ";
			output << cpu_last_bruted_word_size<<" ";
            for (int j = 0; j < MAX_WORD_SIZE; j++)
				//FIIIIX SAVING
            {
                std::cout << (char)alphabet_values[new_word_seed[j]];
                output << new_word_seed[j]<<" ";
                completed_cuda_cycles_count = 0;
            }
            std::cout << "\n";
            output.close();
        }
        completed_cuda_cycles_count++;
    } while (*stop_flag_end_of_bruting != 1);

    std::ofstream output("FINISHED");
    output.close();
    
    clockt_end_timestamp = clock();
    seconds = (clockt_end_timestamp - clockt_start_timestamp) / CLOCKS_PER_SEC;


	//LEGACY CODE  delete[] cpu_word_seed;
	//SaveManager::cleanup();
    delete[] cuda_results;
    delete stop_flag_end_of_bruting;
    delete last_bruted_word_size;
    delete[] new_word_seed;
    delete[] input_hash_list_to_match;
    delete[] found_matching_hashes_array;
	delete[] alphabet_values;
    return 0;



}

inline cudaError_t CudaBrute(
        unsigned int *return_array,
        unsigned int *stop_flag_end_of_bruting,
        unsigned int *last_bruted_word_size,
        unsigned int *new_word_seed,
        unsigned int *found_matching_hashes_array,
        const unsigned int *input_hash_list_to_match
){
    unsigned int *gpu_return_array = 0;
    unsigned int *gpu_new_word_seed = 0;
    unsigned int *gpu_stop_flag_end_of_bruting = 0;
    unsigned int *gpu_alphabet_values = 0;
    unsigned int *gpu_last_bruted_word_size = 0;
    unsigned int *gpu_last_word_bruted = 0;
    unsigned int *gpu_found_matching_hashes_array = 0;
    unsigned int *gpu_input_hash_list = 0;
    cudaError_t cudaStatus;

    // Choose which GPU to run on, change this on a multi-GPU system.
    cudaStatus = cudaSetDevice(0);
    if (cudaStatus != cudaSuccess) {
        fprintf(stderr, "cudaSetDevice failed!  Do you have a CUDA-capable GPU installed?");
        goto Error;
    }

    // Allocate GPU buffers for three vectors (two input_hashes_file, one output)
    cudaStatus = cudaMalloc((void**)&gpu_return_array, THREADSCOUNT * WORD_BUFFER_SIZE * sizeof(unsigned int));
    if (cudaStatus != cudaSuccess) {
        fprintf(stderr, "cudaMalloc failed!");
        goto Error;
    }

    cudaStatus = cudaMalloc((void**)&gpu_last_bruted_word_size, sizeof(unsigned int));
    if (cudaStatus != cudaSuccess) {
        fprintf(stderr, "cudaMalloc failed!");
        goto Error;
    }

    cudaStatus = cudaMalloc((void**)&gpu_last_word_bruted, WORD_BUFFER_SIZE * sizeof(unsigned int));
    if (cudaStatus != cudaSuccess) {
        fprintf(stderr, "cudaMalloc failed!");
        goto Error;
    }

    cudaStatus = cudaMalloc((void**)&gpu_new_word_seed, WORD_BUFFER_SIZE * sizeof(unsigned int));
    if (cudaStatus != cudaSuccess) {
        fprintf(stderr, "cudaMalloc failed!");
        goto Error;
    }
    cudaStatus = cudaMalloc((void**)&gpu_alphabet_values, (alphabet_size+1) * sizeof(unsigned int));
    if (cudaStatus != cudaSuccess) {
        fprintf(stderr, "cudaMalloc failed!");
        goto Error;
    }

    cudaStatus = cudaMalloc((void**)&gpu_stop_flag_end_of_bruting, sizeof(unsigned int));
    if (cudaStatus != cudaSuccess) {
        fprintf(stderr, "cudaMalloc failed!");
        goto Error;
    }
    cudaStatus = cudaMalloc((void**)&gpu_found_matching_hashes_array, THREADSCOUNT * sizeof(unsigned int));
    if (cudaStatus != cudaSuccess) {
        fprintf(stderr, "cudaMalloc failed!");
        goto Error;
    }
    cudaStatus = cudaMalloc((void**)&gpu_input_hash_list, (input_hash_list_to_match[0]+1) *sizeof(unsigned int));
    if (cudaStatus != cudaSuccess) {
        fprintf(stderr, "cudaMalloc failed!");
        goto Error;
    }

    // Copy input_hashes_file vectors from host memory to GPU buffers.
    cudaStatus = cudaMemcpy(gpu_new_word_seed, new_word_seed, WORD_BUFFER_SIZE * sizeof(unsigned int), cudaMemcpyHostToDevice);
    if (cudaStatus != cudaSuccess) {
        fprintf(stderr, "cudaMemcpy failed!");
        goto Error;
    }

    cudaStatus = cudaMemcpy(gpu_alphabet_values, alphabet_values, (alphabet_size+1) * sizeof(unsigned int), cudaMemcpyHostToDevice);
    if (cudaStatus != cudaSuccess) {
        fprintf(stderr, "cudaMemcpy failed!");
        goto Error;
    }

    cudaStatus = cudaMemcpy(gpu_input_hash_list, input_hash_list_to_match, (input_hash_list_to_match[0]+1) * sizeof(unsigned int), cudaMemcpyHostToDevice);
    if (cudaStatus != cudaSuccess) {
        fprintf(stderr, "cudaMemcpy failed!");
        goto Error;
    }
    // Launch a kernel on the GPU with one thread for each element.
    protoBruteKernel << <BLOCKS, THREADS >> >(gpu_return_array, gpu_new_word_seed, gpu_alphabet_values, alphabet_size, gpu_stop_flag_end_of_bruting, word_len_start_size, gpu_last_bruted_word_size, gpu_last_word_bruted, gpu_found_matching_hashes_array, gpu_input_hash_list, WORD_BUFFER_SIZE, MAX_WORD_SIZE, THREADSCOUNT);

    // Check for any errors launching the kernel
    cudaStatus = cudaGetLastError();
    if (cudaStatus != cudaSuccess) {
        fprintf(stderr, "bruteKernel launch failed: %s\n", cudaGetErrorString(cudaStatus));
        goto Error;
    }

    // cudaDeviceSynchronize waits for the kernel to finish, and returns
    // any errors encountered during the launch.
    cudaStatus = cudaDeviceSynchronize();
    if (cudaStatus != cudaSuccess) {
        fprintf(stderr, "cudaDeviceSynchronize returned error code %d after launching bruteKernel!\n", cudaStatus);
        goto Error;
    }

    // Copy output vector from GPU buffer to host memory.

    cudaStatus = cudaMemcpy(return_array, gpu_return_array, THREADSCOUNT * WORD_BUFFER_SIZE * sizeof(unsigned int), cudaMemcpyDeviceToHost);
    if (cudaStatus != cudaSuccess) {
        fprintf(stderr, "cudaMemcpy failed!");
        goto Error;
    }

    cudaStatus = cudaMemcpy(found_matching_hashes_array, gpu_found_matching_hashes_array, THREADSCOUNT * sizeof(unsigned int), cudaMemcpyDeviceToHost);
    if (cudaStatus != cudaSuccess) {
        fprintf(stderr, "cudaMemcpy failed!");
        goto Error;
    }

    cudaStatus = cudaMemcpy(last_bruted_word_size, gpu_last_bruted_word_size, sizeof(unsigned int), cudaMemcpyDeviceToHost);
    if (cudaStatus != cudaSuccess) {
        fprintf(stderr, "cudaMemcpy failed!");
        goto Error;
    }

    cudaStatus = cudaMemcpy(new_word_seed, gpu_last_word_bruted, WORD_BUFFER_SIZE * sizeof(unsigned int), cudaMemcpyDeviceToHost);
    if (cudaStatus != cudaSuccess) {
        fprintf(stderr, "cudaMemcpy failed!");
        goto Error;
    }

    cudaStatus = cudaMemcpy(stop_flag_end_of_bruting, gpu_stop_flag_end_of_bruting, sizeof(unsigned int), cudaMemcpyDeviceToHost);
    if (cudaStatus != cudaSuccess) {
        fprintf(stderr, "cudaMemcpy failed!");
        goto Error;
    }

Error:
    cudaFree(gpu_new_word_seed);
    cudaFree(gpu_return_array);
    cudaFree(gpu_stop_flag_end_of_bruting);
    cudaFree(gpu_last_bruted_word_size);
    cudaFree(gpu_alphabet_values);
    cudaFree(gpu_last_word_bruted);
    cudaFree(gpu_input_hash_list);
    cudaFree(gpu_found_matching_hashes_array);
    return cudaStatus;
}
