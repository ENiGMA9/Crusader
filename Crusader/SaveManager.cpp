#ifndef SAVE_MANAGER_H
#include "SaveManager.h"
#endif

#ifndef _FSTREAM_
#include <fstream>
#endif


#ifndef SAVE_MANAGER_CPP
#define SAVE_MANAGER_CPP

void SaveManager::load(char* filename, int alphabetSize = 0){
	valid = 1;
	unsigned int buffer;
	int counter = 0;

	std::ifstream savefile(filename);
	if (savefile.bad)
	{
		throw "Savefile not found or in use";
	}

	savefile >> buffer;

	while (savefile >> buffer)
	{
		counter++;
	}
	savefile.clear();																//We clear any operation remnants we did on the file
	savefile.seekg(0, std::ios::beg);

	savefile >> session.savedTarget;

	session.savedWord = new unsigned int[counter + 1];
	session.savedWord[0] = counter;

	int iterator = 1;
	while (savefile >> buffer)
	{
		if (alphabetSize != 0)
		{
			if (buffer >= alphabetSize)
			{
				valid = 0;
				break;
			}
		}

		session.savedWord[iterator] = buffer;
		iterator++;
	}
	savefile.close();
}

void SaveManager::save(char* filename){

}

int SaveManager::isValid(){
	return valid;
}

void SaveManager::cleanup(){
	delete[] session.savedWord;
}

#endif