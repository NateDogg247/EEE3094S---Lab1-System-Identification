# EEE3094S Lab 1 - System Identification

**Student:** Junaid Pieters (PTRJUN003) 
**Course:** EEE3094S Control Systems Engineering  
**University:** University of Cape Town  

## Overview

This repository contains the experimental data, MATLAB analysis,
figures and report source used for Lab 1: System Identification.

The aim of the laboratory was to identify a mathematical model of
a simulated spring-mass-damper system using step-response and
frequency-response experiments.

## Identified System

The final estimated model is approximately:

$$
\boldsymbol{G(s)=\frac{2.133}{s^2+2.715s+3.361}}
$$

Approximate parameters:

- DC gain: 0.635
- Damping ratio: 0.740
- Natural frequency: 1.83 rad/s
- Poles: -1.36 ± j1.23

## Repository Structure

- `data/step_test/` - raw step-response measurements
- `data/frequency_test/` - raw sinusoidal measurements
- `matlab/` - MATLAB identification and validation scripts
- `figures/` - generated figures
- `report/` - LaTeX source and final report
