#include <errno.h>
#include <fcntl.h>
#include <signal.h>
#include <stdlib.h>
#include <string.h>
#include <sys/time.h>
#include <sys/wait.h>
#include <unistd.h>

#define POSIX_RUN_OK 0
#define POSIX_RUN_ERR_PIPE 1
#define POSIX_RUN_ERR_FCNTL 2
#define POSIX_RUN_ERR_FORK 3
#define POSIX_RUN_ERR_WAIT 4

static const char *blob_slot(const char *blob, int stride, int index) {
  return blob + (index * stride);
}

static int write_child_errno(int fd, int value) {
  ssize_t written = write(fd, &value, sizeof(value));
  return written == (ssize_t)sizeof(value) ? 0 : -1;
}

static long long now_ms(void) {
  struct timeval tv;
  gettimeofday(&tv, NULL);
  return ((long long)tv.tv_sec * 1000LL) + (tv.tv_usec / 1000LL);
}

static int copy_path(const char *src, char *dst, int dst_len) {
  size_t len = strlen(src);

  if ((int)len + 1 > dst_len) {
    errno = ENAMETOOLONG;
    return -1;
  }

  memcpy(dst, src, len + 1);
  return 0;
}

static int create_capture_file(const char *template_text, char *path_out, int path_out_len, int *fd_out) {
  char *template_copy;
  int fd;

  template_copy = strdup(template_text);
  if (template_copy == NULL) {
    errno = ENOMEM;
    return -1;
  }

  fd = mkstemp(template_copy);
  if (fd < 0) {
    free(template_copy);
    return -1;
  }

  if (copy_path(template_copy, path_out, path_out_len) != 0) {
    int saved_errno = errno;
    close(fd);
    unlink(template_copy);
    free(template_copy);
    errno = saved_errno;
    return -1;
  }

  *fd_out = fd;
  free(template_copy);
  return 0;
}

static int create_stdin_file(const char *stdin_data, int *fd_out) {
  char template_text[] = "/tmp/fgof-process-stdin-XXXXXX";
  int fd = mkstemp(template_text);
  size_t remaining;
  const char *cursor;

  if (fd < 0) {
    return -1;
  }

  unlink(template_text);

  remaining = strlen(stdin_data);
  cursor = stdin_data;
  while (remaining > 0) {
    ssize_t written = write(fd, cursor, remaining);
    if (written < 0) {
      if (errno == EINTR) {
        continue;
      }
      close(fd);
      return -1;
    }
    remaining -= (size_t)written;
    cursor += written;
  }

  if (lseek(fd, 0, SEEK_SET) < 0) {
    close(fd);
    return -1;
  }

  *fd_out = fd;
  return 0;
}

static int apply_env_set(const char *blob, int count, int stride, int errfd) {
  int i;

  for (i = 0; i < count; ++i) {
    const char *entry = blob_slot(blob, stride, i);
    const char *eq = strchr(entry, '=');
    char *name;
    size_t name_len;

    if (entry[0] == '\0') {
      continue;
    }

    if (eq == NULL || eq == entry) {
      write_child_errno(errfd, EINVAL);
      return -1;
    }

    name_len = (size_t)(eq - entry);
    name = (char *)malloc(name_len + 1);
    if (name == NULL) {
      write_child_errno(errfd, ENOMEM);
      return -1;
    }

    memcpy(name, entry, name_len);
    name[name_len] = '\0';

    if (setenv(name, eq + 1, 1) != 0) {
      int saved_errno = errno;
      free(name);
      write_child_errno(errfd, saved_errno);
      return -1;
    }

    free(name);
  }

  return 0;
}

static int apply_env_unset(const char *blob, int count, int stride, int errfd) {
  int i;

  for (i = 0; i < count; ++i) {
    const char *entry = blob_slot(blob, stride, i);

    if (entry[0] == '\0') {
      continue;
    }

    if (unsetenv(entry) != 0) {
      write_child_errno(errfd, errno);
      return -1;
    }
  }

  return 0;
}

int fgof_process_run_basic(const char *program,
                           const char *argv_blob,
                           int argc,
                           int arg_stride,
                           const char *command_line,
                           int use_shell,
                           const char *cwd,
                           const char *stdin_data,
                           int use_stdin,
                           int capture_stdout,
                           int capture_stderr,
                           int timeout_ms,
                           const char *env_set_blob,
                           int env_set_count,
                           int env_set_stride,
                           const char *env_unset_blob,
                           int env_unset_count,
                           int env_unset_stride,
                           char *stdout_path,
                           int stdout_path_len,
                           char *stderr_path,
                           int stderr_path_len,
                           int *exit_code,
                           int *term_signal,
                           int *exec_failed,
                           int *timed_out,
                           int *sys_errno) {
  int errpipe[2];
  int stdin_fd = -1;
  int stdout_fd = -1;
  int stderr_fd = -1;
  int status = 0;
  int child_errno = 0;
  pid_t pid;
  ssize_t read_size;

  stdout_path[0] = '\0';
  stderr_path[0] = '\0';
  *exit_code = -1;
  *term_signal = 0;
  *exec_failed = 0;
  *timed_out = 0;
  *sys_errno = 0;

  if (use_stdin) {
    if (create_stdin_file(stdin_data, &stdin_fd) != 0) {
      *sys_errno = errno;
      return POSIX_RUN_ERR_PIPE;
    }
  }

  if (capture_stdout) {
    if (create_capture_file("/tmp/fgof-process-stdout-XXXXXX", stdout_path, stdout_path_len, &stdout_fd) != 0) {
      *sys_errno = errno;
      if (stdin_fd >= 0) close(stdin_fd);
      return POSIX_RUN_ERR_PIPE;
    }
  }

  if (capture_stderr) {
    if (create_capture_file("/tmp/fgof-process-stderr-XXXXXX", stderr_path, stderr_path_len, &stderr_fd) != 0) {
      *sys_errno = errno;
      if (stdin_fd >= 0) close(stdin_fd);
      if (stdout_fd >= 0) {
        close(stdout_fd);
        unlink(stdout_path);
      }
      return POSIX_RUN_ERR_PIPE;
    }
  }

  if (pipe(errpipe) != 0) {
    *sys_errno = errno;
    if (stdin_fd >= 0) close(stdin_fd);
    if (stdout_fd >= 0) {
      close(stdout_fd);
      unlink(stdout_path);
    }
    if (stderr_fd >= 0) {
      close(stderr_fd);
      unlink(stderr_path);
    }
    return POSIX_RUN_ERR_PIPE;
  }

  if (fcntl(errpipe[1], F_SETFD, FD_CLOEXEC) != 0) {
    *sys_errno = errno;
    close(errpipe[0]);
    close(errpipe[1]);
    if (stdin_fd >= 0) close(stdin_fd);
    if (stdout_fd >= 0) {
      close(stdout_fd);
      unlink(stdout_path);
    }
    if (stderr_fd >= 0) {
      close(stderr_fd);
      unlink(stderr_path);
    }
    return POSIX_RUN_ERR_FCNTL;
  }

  pid = fork();
  if (pid < 0) {
    *sys_errno = errno;
    close(errpipe[0]);
    close(errpipe[1]);
    if (stdin_fd >= 0) close(stdin_fd);
    if (stdout_fd >= 0) {
      close(stdout_fd);
      unlink(stdout_path);
    }
    if (stderr_fd >= 0) {
      close(stderr_fd);
      unlink(stderr_path);
    }
    return POSIX_RUN_ERR_FORK;
  }

  if (pid == 0) {
    close(errpipe[0]);

    if (use_stdin) {
      if (dup2(stdin_fd, STDIN_FILENO) < 0) {
        write_child_errno(errpipe[1], errno);
        _exit(127);
      }
    }

    if (capture_stdout) {
      if (dup2(stdout_fd, STDOUT_FILENO) < 0) {
        write_child_errno(errpipe[1], errno);
        _exit(127);
      }
    }

    if (capture_stderr) {
      if (dup2(stderr_fd, STDERR_FILENO) < 0) {
        write_child_errno(errpipe[1], errno);
        _exit(127);
      }
    }

    if (stdin_fd >= 0) close(stdin_fd);
    if (stdout_fd >= 0) close(stdout_fd);
    if (stderr_fd >= 0) close(stderr_fd);

    if (cwd != NULL && cwd[0] != '\0') {
      if (chdir(cwd) != 0) {
        write_child_errno(errpipe[1], errno);
        _exit(127);
      }
    }

    if (env_set_count > 0) {
      if (apply_env_set(env_set_blob, env_set_count, env_set_stride, errpipe[1]) != 0) {
        _exit(127);
      }
    }

    if (env_unset_count > 0) {
      if (apply_env_unset(env_unset_blob, env_unset_count, env_unset_stride, errpipe[1]) != 0) {
        _exit(127);
      }
    }

    if (use_shell) {
      char *shell_argv[4];
      shell_argv[0] = "/bin/sh";
      shell_argv[1] = "-c";
      shell_argv[2] = (char *)command_line;
      shell_argv[3] = NULL;
      execvp(shell_argv[0], shell_argv);
    } else {
      char **argv;
      int i;

      argv = (char **)malloc((size_t)(argc + 2) * sizeof(char *));
      if (argv == NULL) {
        write_child_errno(errpipe[1], ENOMEM);
        _exit(127);
      }

      argv[0] = (char *)program;
      for (i = 0; i < argc; ++i) {
        argv[i + 1] = (char *)blob_slot(argv_blob, arg_stride, i);
      }
      argv[argc + 1] = NULL;

      execvp(program, argv);
    }

    write_child_errno(errpipe[1], errno);
    _exit(127);
  }

  close(errpipe[1]);
  if (stdin_fd >= 0) close(stdin_fd);
  if (stdout_fd >= 0) close(stdout_fd);
  if (stderr_fd >= 0) close(stderr_fd);

  if (timeout_ms > 0) {
    long long start = now_ms();
    int sigterm_sent = 0;
    int sigkill_sent = 0;
    long long sigterm_at = 0;

    for (;;) {
      pid_t wait_rc = waitpid(pid, &status, WNOHANG);
      if (wait_rc == pid) {
        break;
      }
      if (wait_rc < 0) {
        if (errno == EINTR) {
          continue;
        }
        *sys_errno = errno;
        close(errpipe[0]);
        return POSIX_RUN_ERR_WAIT;
      }

      if (!sigterm_sent && (now_ms() - start) >= timeout_ms) {
        *timed_out = 1;
        kill(pid, SIGTERM);
        sigterm_sent = 1;
        sigterm_at = now_ms();
      } else if (sigterm_sent && !sigkill_sent && (now_ms() - sigterm_at) >= 100) {
        kill(pid, SIGKILL);
        sigkill_sent = 1;
      }

      usleep(10000);
    }
  } else {
    while (waitpid(pid, &status, 0) < 0) {
      if (errno != EINTR) {
        *sys_errno = errno;
        close(errpipe[0]);
        return POSIX_RUN_ERR_WAIT;
      }
    }
  }

  read_size = read(errpipe[0], &child_errno, sizeof(child_errno));
  close(errpipe[0]);

  if (read_size == (ssize_t)sizeof(child_errno)) {
    *exec_failed = 1;
    *sys_errno = child_errno;
    if (stdout_path[0] != '\0') {
      unlink(stdout_path);
      stdout_path[0] = '\0';
    }
    if (stderr_path[0] != '\0') {
      unlink(stderr_path);
      stderr_path[0] = '\0';
    }
    return POSIX_RUN_OK;
  }

  if (WIFEXITED(status)) {
    *exit_code = WEXITSTATUS(status);
  } else if (WIFSIGNALED(status)) {
    *term_signal = WTERMSIG(status);
  }

  return POSIX_RUN_OK;
}
