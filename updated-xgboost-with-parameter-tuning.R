# Predict the house price
**Statement** As a new Kaggler who just created his account a day ago, I am quite excited to hand in my
first submission. Without any professional background in CS/Statistics, I have learned data mining, machine learning
and R by myself. My lack of experience may make the model not perfect, but I do love to share my opinions. And I hope 
my dear experienced Kaggle friends can give me some advice/suggestion/criticism of this project. Thanks in advance.

**Updated** Seems that I have to learn to implement XGBoost model if I want a higher score in the competition. The package
is amazingly convenient, however I also encountered the problem of parameter tuning. Meanwhile, it seems to be true that my 
feature engineering is too naive. With different categorical variables, I need to examine them one by one rather than transform
them to integer directly. I will try to do this later and see the magic of feature engineering.

### Read Data and Load Packages 

```{r,message=FALSE, warning=FALSE}
# Load Packages
library(MASS) 
library(Metrics)
library(corrplot)
library(randomForest)
library(lars)
library(ggplot2)
library(xgboost)
library(Matrix)
library(methods)
library(caret)
```
```{r load}
# Read Data
Training <- read.csv("train.csv")
Test <- read.csv("test.csv")
# Test whether data is successfully loaded
names(Training)

```

After that, the whole procedure has begun. I divide the whole process into four steps:

* Data Cleansing
* Descriptive Analysis
* Model Selection
* Final Prediction


### Data Cleansing
It is important to clean the data with some specific rules, otherwise the precision of result can be jeopardized. After summarizing
training set, it is not diffcult to find that some data columns got too many missing values. We first have look on the number of missing
values in every variable. 


```{r,message=FALSE, warning=FALSE}

Num_NA<-sapply(Training,function(y)length(which(is.na(y)==T)))
NA_Count<- data.frame(Item=colnames(Training),Count=Num_NA)

NA_Count
```

Among 1460 variables, 'Alley',  'PoolQC', 'Fence' and 'MiscFeature' have amazingly high number of missing value. Therefore, I 
have decided to remove those variables. After that, the number of effective variables has shrunken to 75 (excluding id). 

```{r,message=FALSE, warning=FALSE}
Training<- Training[,-c(7,73,74,75)]
```
Then, I transferred dummny variables into numeric form. Due to the intimidating size of dummy variables, I decided to transfer them 
directly by implementing 'as.integer' method. This is why I let the string as factor when reading the data file. The numeric variables
are sorted out in particular for the convenience of descriptive analysis.

```{r,message=FALSE, warning=FALSE}
# Numeric Variables
Num<-sapply(Training,is.numeric)
Num<-Training[,Num]

for(i in 1:77){
  if(is.factor(Training[,i])){
    Training[,i]<-as.integer(Training[,i])
  }
}

# Test
Training$Street[1:50]
```
Finally, for the remaining missing values, I replaced them with zero directly. The data cleansing procedure ends here.

```{r,message=FALSE, warning=FALSE}
Training[is.na(Training)]<-0
Num[is.na(Num)]<-0
```
### Descriptive Analysis

Exploring dataset could be diffcult when the quantity of variables is quite huge. Therefore, I mainly focused on the exploration of numeric
variables in this report. The descriptive analysis of dummy variables are mostly finished by drawing box plots. Some dummy variables, like 'Street',
are appeared to be ineffective due to the extreme box plot. The numeric variables are sorted out before turning dummy variables into numeric form.

We first draw a corrplot of numeric variables. Those with strong correlation with sale price are examined.
```{r,message=FALSE, warning=FALSE}
correlations<- cor(Num[,-1],use="everything")
corrplot(correlations, method="circle", type="lower",  sig.level = 0.01, insig = "blank")
```
'OverallQual','TotalBsmtSF','GarageCars' and 'GarageArea' have relative strong correlation with each other. Therefore, as an example, we plot the correlation
among those four variables and SalePrice.
```{r,message=FALSE, warning=FALSE}
pairs(~SalePrice+OverallQual+TotalBsmtSF+GarageCars+GarageArea,data=Training,
      main="Scatterplot Matrix")
```
The dependent variable (SalePrice) looks having decent linearity when plotting with other variables. However, it is also obvious that some independent variables 
also have linear relationship with others. The problem of multicollinearity is obvious and should be treated when the quantity of variables in regression formula is huge.

The final descriptive analysis I put here would be the relationship between the variable 'YearBu' and Sale Price.

```{r,message=FALSE, warning=FALSE}
p<- ggplot(Training,aes(x= YearBuilt,y=SalePrice))+geom_point()+geom_smooth()
p
```
It is not diffcult to find that the price of house increases generally with the year built, the trend is obvious. 

The workload of data exploration is huge so I decide to end it at here. More details can be digged out by performing descriptive analysis.

### Model Selection

Before implementing models, one should first split the training set of data into 2 parts: a training set within the training set and a test set that can be used for evaluation.
Personally I prefer to split it with the ratio of 6:4, ***But if someone can tell me what spliting ratio is proved to be scienticfic I will be really grateful***

```{r,message=FALSE, warning=FALSE}
# Split the data into Training and Test Set # Ratio: 6:4 ###
Training_Inner<- Training[1:floor(length(Training[,1])*0.6),]
Test_Inner<- Training[(length(Training_Inner[,1])+1):1460,]
```
I will fit three regression models to the training set and choose the most suitable one by checking RMSE value.

#### Model 1: Linear Regression

The first and simplest but useful model is linear regression model. As the first step, I put all variables into the model.
```{r,message=FALSE,warning=FALSE}
reg1<- lm(SalePrice~., data = Training_Inner)
summary(reg1)
```

R Square is not bad, but many variables do not pass the Hypothesis Testing, so the model is not perfect. Potential overfitting will occur if someone insist on using it. Therefore,
the variable selection process should be involved in model construction. I prefer to use Step AIC method.

Several variables still should not be involved in model. By checking the result of Hypothesis Test, I mannually build the final linear regression model.

```{r,message=FALSE,warning=FALSE}
reg1_Modified_2<-lm(formula = SalePrice ~ MSSubClass + LotArea + 
                      Condition2 + OverallQual + OverallCond + 
                      YearBuilt  + RoofMatl +  ExterQual + 
                      BsmtQual + BsmtCond + BsmtFinSF1 + BsmtFinSF2 + 
                      BsmtUnfSF + X1stFlrSF + X2ndFlrSF + BedroomAbvGr + KitchenAbvGr + 
                      KitchenQual + TotRmsAbvGrd + Functional + Fireplaces + FireplaceQu + 
                       GarageYrBlt + GarageCars +  SaleCondition, 
                    data = Training_Inner)
summary(reg1_Modified_2)
```
The R Square is not bad, and all variables pass the Hypothesis Test. The diagonsis of residuals is also not bad. The diagnosis can be viewed below.
```{r,message=FALSE,warning=FALSE}
layout(matrix(c(1,2,3,4), 2, 2, byrow = TRUE))
plot(reg1_Modified_2)
par(mfrow=c(1,1))
```

We check the performance of linear regression model with RMSE value.

```{r,message=FALSE,warning=FALSE}
Prediction_1<- predict(reg1_Modified_2, newdata= Test_Inner)
rmse(log(Test_Inner$SalePrice),log(Prediction_1))
```
#### Model 2: LASSO Regression

For the avoidance of multicollinearity, implementing LASSO regression is not a bad idea. Transferring the variables into the form of matrix, we can automate
the selection of variables by implementing 'lars' method in Lars package.

```{r,message=FALSE,warning=FALSE}
Independent_variable<- as.matrix(Training_Inner[,1:76])
Dependent_Variable<- as.matrix(Training_Inner[,77])
laa<- lars(Independent_variable,Dependent_Variable,type = 'lasso')
plot(laa)
```

The plot is messy as the quantity of variables is intimidating. Despite that, we can still use R to find out the model with least multicollinearity. The selection 
procedure is based on the value of Marrow's cp, an important indicator of multicollinearity. The prediction can be done by the script-chosen best step and RMSE can be used
to assess the model.

```{r,message=FALSE,warning=FALSE}
best_step<- laa$df[which.min(laa$Cp)]
Prediction_2<- predict.lars(laa,newx =as.matrix(Test_Inner[,1:76]), s=best_step, type= "fit")
rmse(log(Test_Inner$SalePrice),log(Prediction_2$fit))
```

#### Model 3: Random Forest

The other model I chose to fit in the training set is Random Forest model. The model, prediction and RMSE calculation can be found below:

```{r,message=FALSE, warning=FALSE}
for_1<- randomForest(SalePrice~.,data= Training_Inner)
Prediction_3 <- predict(for_1, newdata= Test_Inner)
rmse(log(Test_Inner$SalePrice),log(Prediction_3))
```

Obviously, Random Forest may produce the best result within the training set so far. 

#### Model 4: XGBoost 

This amazing package really impressed me! And I have enthusiam to explore it. The first step of XGBoost is to transform the dataset into Sparse matrix.

```{r,message=FALSE,warning=FALSE}
train<- as.matrix(Training_Inner, rownames.force=NA)
test<- as.matrix(Test_Inner, rownames.force=NA)
train <- as(train, "sparseMatrix")
test <- as(test, "sparseMatrix")
# Never forget to exclude objective variable in 'data option'
train_Data <- xgb.DMatrix(data = train[,2:76], label = train[,"SalePrice"])
```
Then I tune the parameters of xgboost model by building a 20-iteration for-loop. **Not sure whether this method is reliable but really time-consuming**
**Updated** Thanks for the advices from my fellow Kaggle friend! Now I understand how to use 'Caret' to perform grid search for the parameters. 
```{r,message=FALSE,warning=FALSE}
# Tuning the parameters #
cv.ctrl <- trainControl(method = "repeatedcv", repeats = 1,number = 3)

xgb.grid <- expand.grid(nrounds = 500,
                        max_depth = seq(6,10),
                        eta = c(0.01,0.3, 1),
                        gamma = c(0.0, 0.2, 1),
                        colsample_bytree = c(0.5,0.8, 1),
                        min_child_weight=seq(1,10)
)

xgb_tune <-train(SalePrice ~.,
                 data=Training_Inner,
                 method="xgbTree",
                 metric = "RMSE",
                 trControl=cv.ctrl,
                 tuneGrid=xgb.grid
)

print(xgb.grid)
```
Then, the parameter can be selected by the random process. Since the process is relatively boring, I just skip it in RMarkdown file and use the optimal parameters 
I got in my local R script for the prediction and evaluation. ** Can I ask some more efficient and intelligent method of parameter tuning from smart Kagglers?
Looking forward to your advice!!**

The model should be tested before making actual prediction.

```{r,message=FALSE,warning=FALSE}

test_data <- xgb.DMatrix(data = test[,2:76])

prediction <- predict(xgb_tune, test_data)
rmse(log(Test_Inner$SalePrice),log(prediction))
```



***END*** Open to any advice/suggestion/criticism. Advice on the choice of other better models is particularily appreciated!!!!!!!!!!!!!!!!!!!!!!!!!