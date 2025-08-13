import time
import os
import time, datetime
import matplotlib.pyplot as plt
import statsmodels.api as sm
import numpy as np

def linear_fit(x, y):
    error_fit = False 
    try:
        results = sm.OLS(y,sm.add_constant(x)).fit()
    except ValueError:
        error_fit = True 
    if ( error_fit == False ):
        error_gain = False 
        try:
            slope = results.params[1]
        except IndexError:
            slope = 0
            error_gain = True
        try:
            constant = results.params[0]
        except IndexError:
            constant = 0
    else:
        slope = 0
        constant = 0
        error_gain = True

    y_fit = np.array(x)*slope + constant
    delta_y = abs(y - y_fit)
    inl = delta_y / (max(y)-min(y))
    peakinl = max(inl)
    return slope, constant, peakinl, error_gain


#a = [-1.303, 58.91, 43.523, 94.6, 2.92, 6.686, 2.516, 27.425, 18.31, 24.87, 5.39, 9.134]
#b = [-20.7, 1092, 807.6, 1752.6, 57, 126.87, 49.30, 510.15, 341.26, 462.66, 102.5, 171.97]

a = [16317, 28691, 6902, 20360, -5276, 87868, 108848, 229747, 139653, 328016, 189500, 249867, 58069, 364637, 305539, 440102]
b = [329289, 553471, 155658, 403864, -67102, 1642971, 2027402, 4248570, 2594738, 6053133, 3510253, 4621117, 1095615, 6724511, 5641345, 8111020]
slope, constant, peakinl, error_gain = linear_fit(a,b)
print (slope, constant, peakinl, error_gain)
#plt.rcParams.update({'font.size': 8})
fig = plt.figure(figsize=(12,8))
plt.plot(a,b, marker='o', color='b')
plt.plot(a,np.array(a)*slope + constant, marker='.', color='r')
plt.show()
plt.close()


