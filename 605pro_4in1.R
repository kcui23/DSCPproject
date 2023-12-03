library(tm)
library(quanteda)
library(stringr)
library(dplyr)
library(tidyr)
library(tidytext)

#########
#使用此代码时文件目录下应有NRC-Lexicon.txt和4个文件夹info,vocab,complex,senti用于存储文件

#输出3个带header的csv，一个txt, csv第一列均为Name,以“10001-8.txt”为例,第一列为数值10001
#包括以下文件：
#作者/书名/年份 的info.csv
#100最高频词及其占比的vocab.txt
#词汇复杂度，句子长度，F-K Grade和 G-F Index的complex.csv
#情感占比的sentiment.csv

#####
#情感词典使用NRC Word-Emotion Association Lexicon
#https://raw.githubusercontent.com/kcui23/stat605_final_project/main/NRC-Lexicon.txt
#使用该词典需要引用：！！！！！
#Saif M. Mohammad and Peter Turney. (2013), ``Crowdsourcing a Word-Emotion Association Lexicon.'' Computational Intelligence, 29(3): 436-465.



##########非常重要！！！！
#####这里要改成command line, arg1是"10001.txt"之类, arg2是具体电子书存储路径，
# 预期在sub里直接用一个（含有文件夹下全部文件名的）txt来调用nameinput
# 当前测试阶段,直接在此处输入更改

# 名称输入,XXX-8.txt之类的也不要紧，后面处理时只取前5位
nameinput = "10001.txt"
#具体电子书存储路径
truedir = "./"


##########以下是运行部分

# 处理路径，准备输入和输出的全部路径，输出默认在运行目录下的info,vocab,complex,senti文件夹
namedir = paste(truedir,nameinput,sep = "")
namenumber <- substr(nameinput, 1, 5)
infoname <- paste("./info/", namenumber, "info.csv", sep = "")
vocabname <- paste("./vocab/",namenumber, "vocab.txt", sep = "")
gradename <- paste("./complex/",namenumber, "complex.csv", sep = "")
sentiname <- paste("./senti/", namenumber, "sentiment.csv", sep = "")

# 读取文本数据
text <- readLines(namedir)

##### 基础信息

# 查找并提取Author和Release Year
author <- NA
year <- NA
if (any(str_detect(text, "Author:"))) {
  author <- str_extract(text[str_detect(text, "Author:")], "Author: (.+)") %>% str_replace("Author: ", "")
}
if (any(str_detect(text, "Release Date:"))) {
  release_date_full <- str_extract(text[str_detect(text, "Release Date:")], "Release Date: .+\\[(.+)\\]") %>% str_replace("Release Date: ", "")
  release_date_full <- gsub("EBook #[0-9]+", "", release_date_full)
  year <- as.numeric(str_extract(release_date_full, "\\b(\\d{4})\\b"))
}
info_df <- data.frame(namenumber, author, year)
info_df[is.na(info_df)] <- ""
# 将数据保存为csv文件
write.table(info_df, infoname, sep = ",", row.names = FALSE, col.names = c("Name","Author","Year"), quote = FALSE)


##### 阅读难度与可读性

# 预处理
corpus <- Corpus(VectorSource(text))
corpus <- tm_map(corpus, content_transformer(tolower))
corpus <- tm_map(corpus, removePunctuation)
corpus <- tm_map(corpus, removeNumbers)
corpus <- tm_map(corpus, stripWhitespace)
dtm <- DocumentTermMatrix(corpus)
mat <- as.matrix(dtm)
word.freq <- rowSums(mat)
word.freq.col <- colSums(mat) 
word.count <- sum(word.freq)

### 高频词汇
# 获取频率最高的100个词并计算占比
top.words <- sort(word.freq.col, decreasing = TRUE)[1:100]
word.proportion <- round(100 * top.words / word.count, 4)
# 将数据保存为txt文件
output.df <- data.frame(Word = names(top.words), Frequency = top.words, Proportion = word.proportion)
write.table(output.df, vocabname, sep = "\t", row.names = FALSE, col.names = TRUE, quote = FALSE)

### 基础数据
# 词汇复杂度计算
vocab.richness <- length(word.freq) / word.count
# 句子长度
sentence.count <- length(unlist(strsplit(text, "[.!?]")))
avg.sentence.length <- word.count / sentence.count

### F-K Grade和 G-F Index
# 计算复杂词数（定义为超过三个音节的词
full.text <- tolower(paste(text, collapse=" "))
syllable.count <- nchar(gsub("[^aeiouy]", "", full.text))
words <- unlist(strsplit(full.text, "\\s+"))
complex.words.count <- sum(nchar(gsub("[aeiouy]+", "&", words)) >= 3)
# 计算 Flesch-Kincaid Grade Level
fk.grade <- 0.39 * (word.count / sentence.count) + 11.8 * (syllable.count / word.count) - 15.59
# 计算 Gunning Fog Index
gf.index <- 0.4 * ((word.count / sentence.count) + 100 * (complex.words.count / word.count))

# 将结果整理成dataframe
results_df <- t(data.frame(c(fk.grade, gf.index, vocab.richness, avg.sentence.length)))
colnames(results_df) <- c("F-KGrade", "G-FIndex", "VocabularyRichness", "SentenceLength")
# 写入CSV文件
results_df <- cbind(Name = namenumber, results_df)
write.csv(results_df, gradename, row.names = FALSE, quote = FALSE)

#####情感分析

# 读取情感词典
emotion_lexicon <- read.table("./NRC-Lexicon.txt", header = FALSE, sep = "\t", col.names = c("word", "emotion", "score"))
emotion_lexicon_wide <- emotion_lexicon %>%
  spread(emotion, score)
# 处理文本数据
text_df <- data.frame(text = text, stringsAsFactors = FALSE) %>%
  unnest_tokens(word, text)
# 匹配情感并计算频率
emotion_freq <- text_df %>%
  inner_join(emotion_lexicon_wide, by = "word") %>%
  select(-word) %>%
  summarise_all(sum, na.rm = TRUE)
total_freq <- sum(emotion_freq)
emotion_freq <- round(100 * emotion_freq / total_freq, 2)
# 将数据保存为CSV文件
emotion_freq <- cbind(Name = namenumber, emotion_freq)
write.table(emotion_freq, sentiname, sep = ",",row.names = FALSE, quote = FALSE)
