library(tm)
library(quanteda)
library(stringr)
library(dplyr)
library(reshape)
library(tidytext)

#########
#使用此代码时文件目录下应有NRC-Lexicon.txt和2个文件夹vocab,total用于存储文件

#输出1个带header的csv，一个txt, csv第一列为Name,以“10001-8.txt”为例,第一列为数值10001
#包括以下文件：
#作者/书名/年份,/词汇复杂度/句子长度/F-K Grade/ G-F Index/ 情感占比  的total.csv
#100最高频词及其占比的vocab.txt


#####
#情感词典使用NRC Word-Emotion Association Lexicon
#https://raw.githubusercontent.com/kcui23/stat605_final_project/main/NRC-Lexicon.txt
#使用该词典需要引用：！！！！！
#Saif M. Mohammad and Peter Turney. (2013), ``Crowdsourcing a Word-Emotion Association Lexicon.'' Computational Intelligence, 29(3): 436-465.


# Command-Line Arguments
args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 2) {
  cat("usage: Rscript main.R <nameinput> <truedir>\n")
  quit(save = "no", status = 1)
}

# Set paths to template spectrum and data directory
nameinput <- args[1]
truedir <- args[2]


##########非常重要！！！！
#####这里要改成command line, arg1是"10001.txt"之类, arg2是具体电子书存储路径，
#全都是字符串！！！！！！！
# 预期在sub里直接用一个（含有文件夹下全部文件名的）txt来调用nameinput
# 当前测试阶段,直接在此处输入更改

processFile <- function(nameinput, truedir) {  
  if (grepl("-", nameinput)) {}
  else {
    ##########以下是运行部分
    
    # 处理路径，准备输入和输出的全部路径，输出默认在运行目录下的info,vocab,complex,senti文件夹
    namedir = paste(truedir,nameinput,sep = "")
    namenumber <- substr(nameinput, 1, 5)
    vocabname <- paste("./vocab/",namenumber, "vocab.csv", sep = "")
    totalname <- paste("./total/", namenumber, "total.csv", sep = "")
    
    # 获取停词
    stop_words <- stopwords("en")
    
    # 读取文本数据
    text <- readLines(namedir)
    
    ##### 基础信息
    
    # 查找并提取Author和Release Year
    author <- NA
    year <- NA
    language <- NA
    # 查找并提取Author
    author_line_index <- which(str_detect(text, "Author:"))[1]
    if (length(author_line_index) > 0) {
      author_line <- text[author_line_index]
      author <- str_extract(author_line, "Author: ([^\r\n]+)") %>% str_replace_all("Author: ", "") %>% str_trim()
    }
    
    # 查找并提取Release Year
    if (any(str_detect(text, "Release Date:"))) {
      release_date_full <- str_extract(text[str_detect(text, "Release Date:")], "Release Date: .+\\[(.+)\\]") %>% str_replace("Release Date: ", "")
      year <- as.numeric(str_extract(release_date_full, "\\b(\\d{4})\\b"))
    }
    
    # 查找并提取Language
    if (any(str_detect(text, "Language:"))) {
      language_line <- text[str_detect(text, "Language:")]
      language <- str_extract(language_line, "Language: ([^\\n]+)") %>% str_replace("Language: ", "") %>% str_trim()
    }
    
    # 创建输出数据框
    info_df <- data.frame(namenumber, author, year, language)
    colnames(info_df) <- c("Name", "Author", "Year", "Language")
    info_df[is.na(info_df)] <- ""
    
    ##### 阅读难度与可读性
    
    # 预处理
    corpus <- Corpus(VectorSource(text))
    corpus <- tm_map(corpus, content_transformer(tolower))
    corpus <- tm_map(corpus, removePunctuation)
    corpus <- tm_map(corpus, removeNumbers)
    corpus <- tm_map(corpus, stripWhitespace)
    corpus <- tm_map(corpus, removeWords, stop_words)
    dtm <- DocumentTermMatrix(corpus)
    mat <- as.matrix(dtm)
    word.freq <- rowSums(mat)
    word.freq.col <- colSums(mat) 
    word.count <- sum(word.freq)
    
    # 获取频率最高的100个词并计算占比
    top.words <- sort(word.freq.col, decreasing = TRUE)[1:200]
    word.proportion <- round(100 * top.words / word.count, 4)
    
    # 将数据保存为csv文件
    output.df <- data.frame(Word = names(top.words), Frequency = top.words, Proportion = word.proportion)
    write.csv(output.df, vocabname, row.names = FALSE, quote = FALSE)
    
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
    
    #####情感分析
    
    # 读取情感词典
    emotion_lexicon <- read.table("./NRC-Lexicon.txt", header = FALSE, sep = "\t", col.names = c("word", "emotion", "score"))
    emotion_lexicon_wide <- cast(emotion_lexicon, word ~ emotion, value = "score")
    # 处理文本数据
    text <- data.frame(text = text, stringsAsFactors = FALSE)
    words <- unlist(strsplit(text$text, " "))
    text_df <- data.frame(word = words)
    # 匹配情感并计算频率
    emotion_freq <- text_df %>%
      inner_join(emotion_lexicon_wide, by = "word") %>%
      select(-word) %>%
      summarise_all(sum, na.rm = TRUE)
    total_freq <- sum(emotion_freq)
    emotion_freq <- round(100 * emotion_freq / total_freq, 2)
    
    # 将数据保存为CSV文件
    total_df <- cbind(info_df, results_df)
    total_df <- cbind(total_df, emotion_freq)
    write.table(total_df, totalname, sep = ",",row.names = FALSE, quote = FALSE)
  }
}

processFile(nameinput, truedir)
