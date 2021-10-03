#include <unistd.h>

int main()
{
	int ret;
	char c;
	usleep(350 * 1000);
	while ((ret = read(0, &c, 1)) > 0) {
		usleep(35 * 1000);
		if ((ret = write(1, &c, 1)) <= 0)
			break;
	}
	return ret;
}
