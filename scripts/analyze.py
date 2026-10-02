#!/usr/bin/env python3
"""Performance and protocol analysis of the sink trace written by the testbench.

Each row is one clock cycle: s_valid s_ready s_data m_valid m_ready m_data.
"# phase N" lines start a new phase; other "#" lines are comments.
Exit status must be 1 if any check fails, 0 otherwise.
"""
import argparse
import sys
import re  # regexp
from dataclasses import dataclass, field


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("trace", nargs="?", default="build/sink.txt")
    a = ap.parse_args(argv)

    # TODO: read a.trace, report the measurements and run the checks.
    print(f"TODO: analyze {a.trace}")

    ### OPERATING ON FILE ###
    # opening a trace file produced by testbench
    try:
        with open(a.trace, "r") as f:
            lines = f.readlines()
    except OSError as exc:
        print(f"ERROR: cannot read {a.trace}")
        return 1

    # returns True if on the input handshake valid && ready == 1
    def input_handshake(cycle):
        s_valid, s_ready, s_data, m_valid, m_ready, m_data = cycle
        return s_ready == 1 and s_valid == 1

    # returns True if on the output handshake valid && ready == 1
    def output_handshake(cycle):
        s_valid, s_ready, s_data, m_valid, m_ready, m_data = cycle
        return m_ready == 1 and m_valid == 1

    # structure of dictionary
    # {
    # 1: [cycle1, cycle2, ...],
    # 2: [cycle1, ...],
    # }
    phases = {}

    # list for numbers of lines with errors
    parsed_cycles = []

    # regexp for data
    data_regexp = re.compile(
        r"^\s*([01])\s+([01])\s+([0-9a-fA-FxX]+)\s+"
        r"([01])\s+([01])\s+([0-9a-fA-FxX]+)\s*$"
    )
    # regexp for phase lines
    phase_regexp = re.compile(
        r"^\s*#\s*phase\s+(\d+)\s*$", re.IGNORECASE
    )

    for line_no, raw_line in enumerate(lines, start=1):

        line = raw_line.strip()  # deleting a white characters from end and beginning

        # phase
        match_phase = phase_regexp.match(line)
        if match_phase:
            current_phase = int(match_phase.group(1))
            phases.setdefault(current_phase, [])
            continue

        # comments
        if line.startswith("#"):
            continue

        if current_phase is None:
            print(f"ERROR: line {line_no}: data starts without phase")
            parsed_cycles.append((line_no, current_phase, None))
            continue

        # data
        match_data = data_regexp.match(line)
        if not match_data:
            print(f"ERROR: line {line_no}: invalid trace line : {line}")
            parsed_cycles.append((line_no, current_phase, None))
            continue

        # getting all signals
        s_valid = int(match_data.group(1))
        s_ready = int(match_data.group(2))
        s_data = match_data.group(3).lower()
        m_valid = int(match_data.group(4))
        m_ready = int(match_data.group(5))
        m_data = match_data.group(6).lower()

        cycle = (s_valid, s_ready, s_data, m_valid, m_ready, m_data)

        #adding to dictionary at current phase the current cycle
        phases[current_phase].append(cycle)

        #adding to list analyzed lines in current phase 
        parsed_cycles.append((line_no, current_phase, cycle))

    errors = []

    for line_no, phase, cycle in parsed_cycles:
        if cycle is None:
            errors.append(f"phase: {phase} line: {line_no}: invalid trace data")

    if not phases:
        errors.append("trace contain no phases")

    ### OPERTING ON DATA FROM FILE sink.txt ###

    print(f"Trace: {a.trace}")
    print()

    ### NUMBER OF WORDS TRANSMITTED ON THE INPUT AND OUTPUT SIDES ###
    # process the directionary phases one by one
    for phase_no in sorted(phases):

        # phase_no is a list od cycles form current analyzed phase
        cycles = phases[phase_no]
        cycle_count = len(cycles)  # number of cycles in analyzed phase

        # handshake counters
        input_count = 0
        output_count = 0

        # backpressure counters
        input_backpressure = 0
        output_backpressure = 0

        # list of send words and collected words
        input_words = []
        output_words = []

        # variables for getting latency 
        first_input_cycle = None
        first_output_cycle = None

        # loop over all cycles in a given phase
        for cycle_no, cycle in enumerate(cycles):
            s_valid, s_ready, s_data, m_valid, m_ready, m_data = cycle

            # Analyze of INPUT interface
            if input_handshake(cycle):
                input_count += 1
                input_words.append(s_data)

                if first_input_cycle is None:
                    first_input_cycle = cycle_no

            # cycles with backpressure
            if s_valid == 1 and s_ready == 0:
                input_backpressure += 1

            # Analyze of OUTPUT interface
            if output_handshake(cycle):
                output_count += 1
                output_words.append(m_data)

                if first_output_cycle is None:
                    first_output_cycle = cycle_no

            # cycles with backpressure
            if m_valid == 1 and m_ready == 0:
                output_backpressure += 1

        ### THROUGHPUT IN WORDS PER CLOCK CYCLE ###
        input_throughput = (input_count / cycle_count if cycle_count > 0 else 0)
        output_throughput = (output_count / cycle_count if cycle_count > 0 else 0)

        ### LATENCY in cycles of clk ###
        if first_input_cycle is not None and first_output_cycle is not None:
            latency = first_output_cycle - first_input_cycle
        else:
            latency = None

        ### REPORT FROM CURRENT PHASE ###
        print(f"Phase:               {phase_no}: ")
        print(f"cycles:              {cycle_count}")
        print(f"input words count:   {input_count}")
        print(f"output words count:  {output_count}")
        print(f"input throughput:    {input_throughput:.3f} words/cycle")
        print(f"output throughput:   {output_throughput:.3f} words/cycle")
        print(f"input backpressure:  {input_backpressure} cycles")
        print(f"output backpressure: {output_backpressure} cycles")

        if latency is None:
            print("latency: N/A")
        else:
            print(f"latency:             {latency} cycles")

        print()

        ### HANDSHAKE PROTOCOLS ON BOTH SIDES ###

        ### INPUT SIDE ###
        previous_waiting_data = None  # beginning
        for cycle_no, cycle in enumerate(cycles):
            s_valid, s_ready, s_data, m_valid, m_ready, m_data = cycle

            if s_valid == 1 and s_ready == 0:
                if previous_waiting_data is not None:
                    if ("x" not in previous_waiting_data and "x" not in s_data and previous_waiting_data != s_data):
                        errors.append(f"phase {phase_no}, cycle {cycle_no}: "
                                      f"s_data changed while s_valid=1 and s_ready=0")
                previous_waiting_data = s_data
            else:
                # reset the memory because the waiting condition is no longer effect valid=1 & ready=1
                previous_waiting_data = None

        ### OUTPUT SIDE ###
        previous_waiting_data = None
        for cycle_no, cycle in enumerate(cycles):
            s_valid, s_ready, s_data, m_valid, m_ready, m_data = cycle

            if m_valid == 1 and m_ready == 0:
                if previous_waiting_data is not None:
                    if ("x" not in previous_waiting_data and "x" not in m_data and previous_waiting_data != m_data):
                        errors.append(f"phase {phase_no}, cycle {cycle_no}: "
                                      f"m_data changed while m_valid=1 and m_ready=0")
                previous_waiting_data = m_data
            else:
                # reset the memory because the waiting condition is no longer effect valid=1 & ready=1
                previous_waiting_data = None

        ### CHECK IF EVERY WORD THAT ENTERED THE MODULE DURING A GIVEN PHASE LEAVES IT DURING THE SAME PHASE ###
        if input_count != output_count:
            errors.append(f"phase {phase_no}: input/output count mismatch"
                          f"numbers of in: {input_count} != numbers of out: {output_count}")

        if len(input_words) == len(output_words):
            for word_no, (input_word, output_word) in enumerate(zip(input_words, output_words)):  # the same cycle
                if "x" not in input_word and "x" not in output_word:
                    if input_word != output_word:
                        errors.append(f"phase {phase_no}: word_number {word_no}:  mismatch "
                                      f"in: {input_word} != out: {output_word}")

        ### PHASE 1 RULES ###
        if phase_no == 1:
            for cycle_no, cycle in enumerate(cycles):
                s_valid, s_ready, s_data, m_valid, m_ready, m_data = cycle

                # FIRST RULE (input transfer on every cycle)
                if not (s_ready == 1 and s_valid == 1):  # no transfer in that cycle
                    errors.append(f"phase {phase_no}: cycle {cycle_no}: "
                                  f"expected input transfer every cycle")
                # SECOND RULE
                if s_ready == 0:
                    errors.append(f"phase {phase_no}: cycle {cycle_no}: s_ready = 0 ")

                # THIRD RULE (output transfer on every cycle)
                if not (m_ready == 1 and m_valid == 1):  # no transfer in that cycle
                    errors.append(f"phase {phase_no}: cycle {cycle_no}: "
                                  f"expected output transfer every cycle")

    print()
    if errors:
        print("CHECKS: FAILS")
        for error in errors:
            print(f"ERROR: {error}")

        return 1

    print("CHECKS: PASS")
    return 0


if __name__ == "__main__":
    sys.exit(main())
