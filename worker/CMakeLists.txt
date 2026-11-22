include(BuildVigilApplication)

build_vigil_application(vigil-worker
	NAME Worker
	WINDOWS_ICON data/vigil-worker.ico
	SOURCES
	src/FeatureWorkerManagerConnection.cpp
	src/FeatureWorkerManagerConnection.h
	src/main.cpp
	src/VigilWorker.cpp
	src/VigilWorker.h
	)
