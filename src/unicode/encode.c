#include <stdio.h>
#include <stdlib.h>
#include <limits.h>
#include <string.h>
#include <assert.h>

#define NMAX 2048
#define NTBL 5

static const int table_width[NTBL][2] = {
    //{ 8,  8 },
    //{ 10, 6 },
    //{ 12, 12 },
    { 16, 16 },
    { 32, 32 }
};

static unsigned interval[NMAX][2];
static unsigned cost[NMAX][NMAX];

#define MAKE_COST(size, time) (((size) << 16) | (time))
#define SIZE_COST(c) ((c) >> 16)
#define TIME_COST(c) ((c) & 0xFFFF)

static unsigned min(unsigned x, unsigned y)
{
    return (x < y) ? x : y;
}

static unsigned max(unsigned x, unsigned y)
{
    return (x < y) ? y : x;
}

static unsigned table_cost(int t, int i, int j)
{
    unsigned bound, s;
    int k;

    assert(0 <= t && t < NTBL);
    assert(i <= j);

    if (table_width[t][0] < 32) {
        bound = 1 << table_width[t][0];
        if (interval[j][0] - interval[i][0] >= bound)
            return UINT_MAX;
    }
    if (table_width[t][1] < 32) {
        bound = 1 << table_width[t][1];
        for (k = i; k <= j; k++) {
            if (interval[k][1] - interval[k][0] >= bound)
                return UINT_MAX;
        }
    }

    s = (table_width[t][0] + table_width[t][1] + 7) / 8;
    if (table_width[t][0] == 32) {
        return MAKE_COST(s * (j - i + 1), 0);
    } else {
        return MAKE_COST(4 + s * (j - i + 1), 0);
    }
}

static unsigned split_cost(int i, int k, int j)
{
    unsigned c1, c2;

    assert(i <= k && k + 1 <= j);

    c1 = cost[i][k];
    c2 = cost[k + 1][j];
    return MAKE_COST(8 + SIZE_COST(c1) + SIZE_COST(c2),
                     1 + max(TIME_COST(c1), TIME_COST(c2)));
}

static unsigned min_split_cost(int i, int j)
{
    int k;
    unsigned ymin = UINT_MAX;

    assert(i <= j);
    for (k = i; k < j; k++) {
        ymin = min(ymin, split_cost(i, k, j));
    }
    return ymin;
}

static void optimize(int n)
{
    int i, j, k, t;
    unsigned y;

    assert(n > 0);
    for (k = 0; k < n; k++) {
        for (i = 0; i + k < n; i++) {
            j = i + k;
            for (t = 0, y = UINT_MAX; t < NTBL; t++) {
                y = min(y, table_cost(t, i, j));
            }
            cost[i][j] = min(y, min_split_cost(i, j));
        }
    }
    fprintf(stderr, "# final cost = (%u, %u)\n",
            SIZE_COST(cost[0][n - 1]), TIME_COST(cost[0][n - 1]));
}

static void print_shifted_table(int i, int j, int shift)
{
    int k;

    for (k = i; k <= j; k++) {
        printf(" (%d %d)",
               interval[k][0] - shift,
               interval[k][1] - shift);
    }
}

static void print_rep(int n, int c, int newline)
{
    int k;

    for (k = 0; k < n; k++)
        putchar(c);
    if (newline)
        putchar('\n');
}

static void print_result_lisp(int p, int i, int j, int b)
{
    int k, t;

    assert(i <= j);

    print_rep(p, ' ', 0);

    for (t = 0; t < NTBL; t++) {
        if (cost[i][j] == table_cost(t, i, j)) {
            printf("(table-%d-%d #x%X",
                   table_width[t][0], table_width[t][1],
                   interval[i][0]);
            print_shifted_table(i, j, interval[i][0]);
            print_rep(1 + b, ')', 1);
            return;
        }
    }
    for (k = i; k < j; k++) {
        if (cost[i][j] == split_cost(i, k, j)) {
            printf("(split #x%X ; %d %d %d\n", interval[k][0], i, k, j);
            print_result_lisp(p + 1, i, k, 0);
            print_result_lisp(p + 1, k + 1, j, 1 + b);
            return;
        }
    }
}

static void print_asm_code(const char *name, int i, int j)
{
    int k, t, s;

    assert(i <= j);

    printf("  .L_%d_%d:\n", i, j);

    for (t = 0; t < NTBL; t++) {
        if (cost[i][j] == table_cost(t, i, j)) {
            s = (table_width[t][0] + table_width[t][1]) / 8;
            printf("    sub eax, 0x%X\n", interval[i][0]);
            printf("    mov ebx, %s_data.T_%d_%d\n", name, i, j);
            printf("    mov ecx, %d\n", j - i + 1);
            printf("    jmp unicode_bsearch_%d_%d\n", table_width[t][0], table_width[t][1]);
            return;
        }
    }
    for (k = i; k < j; k++) {
        if (cost[i][j] == split_cost(i, k, j)) {
            printf("    cmp eax, 0x%X\n", interval[k][0]);
            printf("    jae .L_%d_%d\n", k + 1, j);
            print_asm_code(name, i, k);
            print_asm_code(name, k + 1, j);
            return;
        }
    }
}

static void print_asm_data_pair(int w1, int w2, unsigned c1, unsigned c2)
{
    char q[5] = { 0, 'b', 'w', 0, 'd' };

    if (w1 % 8 == 0 && w1 == w2) {
        printf("    d%c 0x%X, 0x%X\n", q[w1/8], c1, c2);
    } else if (w1 == 12 && w2 == 12) {
        printf("    db 0x%02X, 0x%02X, 0x%02X\n",
               (c1 & 0xFF),
               (c2 & 0xFF),
               (c1 >> 8) | ((c2 >> 8) << 4));
    } else if (w1 == 10 && w2 == 6) {
        printf("    dw 0x%04X\n", c1 + (c2 << 10));
    } else {
        fprintf(stderr, "internal error (%s:%c)\n", __FILE__, __LINE__);
        exit(EXIT_FAILURE);
    }
}

static void print_asm_data(int i, int j)
{
    int k, t;

    assert(i <= j);

    for (t = 0; t < NTBL; t++) {
        if (cost[i][j] == table_cost(t, i, j)) {
            printf("    align 4\n");
            printf(" .T_%d_%d:\n", i, j);
            for (k = i; k <= j; k++) {
                print_asm_data_pair(table_width[t][0],
                                    table_width[t][1],
                                    interval[k][0] - interval[i][0],
                                    interval[k][1] - interval[k][0]);
            }
            return;
        }
    }
    for (k = i; k < j; k++) {
        if (cost[i][j] == split_cost(i, k, j)) {
            print_asm_data(i, k);
            print_asm_data(k + 1, j);
            return;
        }
    }
}

static int load_intervals(FILE *fr)
{
    static char buf[256];
    unsigned a = 0, b = 0, c, d;
    int r, n = 0, s = 0;

    while (NULL != fgets(buf, sizeof(buf), fr)) {
        if (n >= NMAX - 1) {
            fprintf(stderr, "input too big!\n");
            exit(EXIT_FAILURE);
        }
        r = sscanf(buf, "%x..%x", &c, &d);
        switch (r) {
            case 1:
                d = c;
            case 2:
                if (s && c == b + 1) {
                    b = d;
                } else if (s) {
                    interval[n][0] = a;
                    interval[n][1] = b;
                    n++;
                    a = c;
                    b = d;
                } else {
                    a = c;
                    b = d;
                }
                s = 1;
                break;
            default:
                fprintf(stderr, "cannot parse input line:\n%s\n",
                        buf);
                exit(EXIT_FAILURE);
        }
    }
    if (s) {
        interval[n][0] = a;
        interval[n][1] = b;
        n++;
    }

    fprintf(stderr, "# loaded %d intervals\n", n);
    return n;
}

int main(int argc, char *argv[])
{
    int n;

    (void) argc;
    (void) argv;

    n = load_intervals(stdin);
    optimize(n);

    if (argc >= 3 && 0 == strcmp(argv[1], "-asm")) {
        printf(";; %s data start\n", argv[2]);
        printf("%s_data:\n", argv[2]);
        print_asm_data(0, n - 1);
        printf(";; %s data end\n", argv[2]);
        printf(";; %s code start\n", argv[2]);
        printf("%s_code:\n", argv[2]);
        print_asm_code(argv[2], 0, n - 1);
        printf(";; %s code end\n", argv[2]);
    } else {
        print_result_lisp(0, 0, n - 1, 0);
    }
    return 0;
}
