# ProgettoAerodinamico

Credits:

- HessSmith solver originally developed by Federico Messanelli (federico.messanelli@polimi.it).


## Hess Smith: documentation

__Single airfoil case__: `[Cl, Cd, Cp, maxdCp] = solverHS(npoint, aname, alpha, pltFlag)`, where:
- _npoint_ is (half) the number of points used to generate geometry.
- _aname_ is a row vector, each component corresponding to the parameters describing airfoil geometry.
- _alpha_ is the angle of attack.
- _pltFlag_ is __optional__, plots airfoil geometry if `true`.

As for the outputs:

- _Cl_ and _Cd_ are of course the coefficients of lift and drag of the profile.
- _Cp_ contains the chord distribution of pressure coefficient (possibly deprecated).
- _maxdCp_ is a matrix containing values of maximum $\Delta C_P$; each row corresponds to an airfoil, first column corresponts to lower part, second column to upper part.

Example:
```MATLAB
arflPar = [0.3, 0.6, 0, 0, 0.3, 0.12, 0.3, 1.5];
solverHS(80, arflPar, 3);
```

__Multiple airfoil case__: `[Cl, Cd, Cp, maxdCp] = solverHS(npoint, aname, alpha, dist, crel, pltFlag)`, where:
- _npoint_ is (half) the number of points used to generate geometry.
- _aname_ is a matrix, each row corresponding to an airfoil (no. rows = AirfNumb) and containing the parameters needed to define the airfoil.
- _alpha_ is a row vector, containing angles of attack of the airfoils (all angles are expressed in an absolute frame).
- _dist_ is a matrix, each row corresponding to an airfoil; columns correspond to the x and y components of the position of the leading edge, expressed in a body frame attached to the first airfoil (x axis parallel to chord, centered on the leading edge). Notice that the first airfoil is omitted (as its row would always be [0,0]), thus effectively reducing the number of rows to AirfNumb-1.
- _crel_ is a column vector; each component corresponds to the chord of the corresponding airfoil, adimensionalised on the chord of the first airfoil. Again, first airfoil is omitted (since its row would always be [1]), and the length of the vector is AirfNumb-1.
- _pltFlag_ is __optional__, plots airfoil geometry if `true`.

Keep in mind that the chord of the first airfoil is always 1 (thus the "relative chord" of the other airfoils is effectively ther chord).

For the outputs, see single airfoil case.

Example:
```MATLAB
arflPar = [0.3, 0.6, 0, 0, 0.3, 0.12, 0.3, 1.5;
           0.3, 0.6, 0, 0, 0.3, 0.12, 0.3, 1.5];
solverHS(80, arflPar, [3, 6], [1.05, -0.05], 0.3);
```



## Straight perfomance

The straight selected for the project is the straight between turn 2 and turn 3 of Baku City Circuit.

The evaluation of time needed to run this straight is performed by ```[T_sector] = sector(CL, CD, fig)```

- _CL_ is a vector containing the rear wing CL when DRS is closed and when DRS is open.
- _CD_ is a vector containing the rear wing CD when DRS is closed and when DRS is open.
- _fig_ creates figures of straight performances if ```true```.

Example: 

```matlab
CD = [1.169, 0.969];
CL = [4.846, 4.346];

[T_sector] = sector(CL, CD,true);
```



## Coding guidelines

- __never__ push code to 'origin master'
- always run code from `ProgettoAerodinamico` folder; do not open subfolders in MATLAB
    - to do this, run the script `addPaths`; this will make all files and functions in subfolders available from the folder `ProgettoAerodinamico`
    - it might be useful to run `addPaths` even before programming, so that MATLAB linter can correctly access all files in subfolders
- keep in mind that commands such `checkout` and `pull` __overwrite your files__
- commit often and use meaningful commit messages
- __test your code__ before committing

## Useful stuff
- easy git guide: http://rogerdudler.github.io/git-guide/
- git cheatsheet: https://github.github.com/training-kit/
- how to ignore files with `.gitignore`: https://git-scm.com/docs/gitignore
