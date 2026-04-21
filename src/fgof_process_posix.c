#include <errno.h>
#include <fcntl.h>
#include <stdlib.h>
#include <string.h>
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
                           const char *env_set_blob,
                           int env_set_count,
                           int env_set_stride,
                           const char *env_unset_blob,
                           int env_unset_count,
                           int env_unset_stride,
                           int *exit_code,
                           int *term_signal,
                           int *exec_failed,
                           int *sys_errno) {
  int errpipe[2];
  pid_t pid;
  int status;
  int child_errno = 0;
  ssize_t read_size;

  *exit_code = -1;
  *term_signal = 0;
  *exec_failed = 0;
  *sys_errno = 0;

  if (pipe(errpipe) != 0) {
    *sys_errno = errno;
    return POSIX_RUN_ERR_PIPE;
  }

  if (fcntl(errpipe[1], F_SETFD, FD_CLOEXEC) != 0) {
    *sys_errno = errno;
    close(errpipe[0]);
    close(errpipe[1]);
    return POSIX_RUN_ERR_FCNTL;
  }

  pid = fork();
  if (pid < 0) {
    *sys_errno = errno;
    close(errpipe[0]);
    close(errpipe[1]);
    return POSIX_RUN_ERR_FORK;
  }

  if (pid == 0) {
    close(errpipe[0]);

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
  read_size = read(errpipe[0], &child_errno, sizeof(child_errno));
  close(errpipe[0]);

  while (waitpid(pid, &status, 0) < 0) {
    if (errno != EINTR) {
      *sys_errno = errno;
      return POSIX_RUN_ERR_WAIT;
    }
  }

  if (read_size == (ssize_t)sizeof(child_errno)) {
    *exec_failed = 1;
    *sys_errno = child_errno;
    return POSIX_RUN_OK;
  }

  if (WIFEXITED(status)) {
    *exit_code = WEXITSTATUS(status);
  } else if (WIFSIGNALED(status)) {
    *term_signal = WTERMSIG(status);
  }

  return POSIX_RUN_OK;
}
