"""Daily cadence sweep (stub).

One timer tick per day at 08:00 UTC. In Phase 4a this walks every
(chronicle, contributor) pair and decides whether a prompt is due: weekly if 7d
elapsed, monthly if 30d elapsed, special-occasions only on calendar/milestone
events, and ``none`` skips proactive prompts entirely. For now it only proves
the timer trigger is registered and firing.

Registered as a blueprint in ``function_app.py``: a trigger module that is not
registered there never reaches the host's route table.
"""

import logging

import azure.functions as func

bp = func.Blueprint()


@bp.timer_trigger(schedule="0 0 8 * * *", arg_name="timer", run_on_startup=False)
def timer_cadence(timer: func.TimerRequest) -> None:
    logging.info("cadence sweep tick: past_due=%s", timer.past_due)
