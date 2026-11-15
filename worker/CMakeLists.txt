include(BuildVigilApplication)

build_vigil_application(vigil-worker
	NAME Worker
	SOURCES
	src/FeatureWorkerManagerConnection.cpp
	src/FeatureWorkerManagerConnection.h
	src/main.cpp
	src/VigilWorker.cpp
	src/VigilWorker.h
	)
