#include <vector>
#include <queue>
#include <thread>
#include <iostream>
#include <functional>
#include <utility>
#include <mutex>
#include <condition_variable>
#include <future>
#include <stdexcept>
#include <assert.h>

class ThreadPool {
 public:
   static const int THREAD_SIZE = 3;
   enum TaskLevel {LEVEL0, LEVEL1, LEVEL2};
   typedef std::function<void()> Task;
   typedef std::pair<TaskLevel, Task> TaskPair;

   ThreadPool(int thread_size = 5) : thread_size_(thread_size) { }
   ~ThreadPool();

   void Start();
   void Stop();
   void WaitForCompletion();
   template<class F, class... Args>
   auto AddTask(F&& f, Args&&... args) ->std::future<decltype(f(args...))>;
 private:
   ThreadPool(const ThreadPool&);
   const ThreadPool& operator=(const ThreadPool&);
   struct TaskPriorityCmp
   {
     bool operator() (const ThreadPool::TaskPair p1, const ThreadPool::TaskPair p2)
     {
       return p1.first > p2.first;
     }
   };
   
   void ThreadLoop();
   Task take();

   typedef std::vector<std::thread*> Threads;
   typedef std::priority_queue<TaskPair, std::vector<TaskPair>, TaskPriorityCmp> Tasks;

   Threads threads_;
   Tasks tasks_;
   std::mutex mutex_;
   std::condition_variable cond_, cond_wait_;
   bool is_started_;
   int thread_size_;
};

ThreadPool::~ThreadPool()
{
  if (is_started_)
  {
    Stop();
  }
}

void ThreadPool::Start() {
  assert(threads_.empty());
  is_started_ = true;
  threads_.reserve(thread_size_);
  for (int i = 0; i < thread_size_; i ++) {
    threads_.push_back(new std::thread(std::bind(&ThreadPool::ThreadLoop, this)));
  }
}

void ThreadPool::Stop() {
  {
    std::unique_lock<std::mutex> lock(mutex_);
    is_started_ = false;
    cond_.notify_all();
  }

  for (Threads::iterator it = threads_.begin(); it != threads_.end(); ++it) {
    (*it)->join();
    delete *it;
  }
  threads_.clear();
}

void ThreadPool::WaitForCompletion() {
  {
    std::unique_lock<std::mutex> lock(mutex_);
    while (is_started_ && !tasks_.empty()) {
      cond_wait_.wait(lock);
    }
  }
}

// get a task from threadpool
ThreadPool::Task ThreadPool::take() {
  std::unique_lock<std::mutex> lock(mutex_);
  // if task queue is empty, wait
  while (tasks_.empty() && is_started_) {
    cond_.wait(lock);
  }

  Task task;
  Tasks::size_type size = tasks_.size();
  if (!tasks_.empty() && is_started_) {
    task = tasks_.top().second;
    tasks_.pop();
    assert(size - 1 == tasks_.size());
  }
  return task;
}

template<class F, class... Args>
auto ThreadPool::AddTask(F&& f, Args&&... args) ->std::future<decltype(f(args...))> {
  std::unique_lock<std::mutex> lock(mutex_);
  using RetType = decltype(f(args...));
  // return a function type
  auto task = std::make_shared<std::packaged_task<RetType()> >(std::bind(std::forward<F>(f), std::forward<Args>(args)...));
  std::future<RetType> future = task->get_future();
  TaskPair task_pair(LEVEL2, [task](){
    (*task)();
  });
  tasks_.push(task_pair);
  cond_.notify_one();
  return future;
}

void ThreadPool::ThreadLoop()
{
  while (is_started_)
  {
    Task task = take();
    if (task) {
      task();
      cond_wait_.notify_all();
    }
  }
}

/*
void print(int start, int end) {
 for (int i = start; i < end; i ++) {
   std::cout<<"i:"<<i<<std::endl;
 }
}

int main(void) {
  int loop = 1000000;
  int task_count = 10;
  int thread_pool_size = 2;
  ThreadPool t(thread_pool_size);
  t.Start();
  for (int i = 0; i < task_count; i ++) {
    t.AddTask(print, i * loop / task_count, (i + 1) * loop / task_count);
  }
  t.WaitForCompletion();
  t.Stop();
  return 0;
}
*/
