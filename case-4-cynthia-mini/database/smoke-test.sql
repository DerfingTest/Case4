USE CynthiaMini;
GO

SELECT COUNT(*) AS OpenVacancies FROM dbo.Vacancies WHERE Status = 'OPEN';
SELECT COUNT(*) AS CandidateCount FROM dbo.Candidates;
SELECT COUNT(*) AS VacancyCount FROM dbo.Vacancies;
SELECT COUNT(*) AS ApplicationCount FROM dbo.Applications;
SELECT COUNT(*) AS HistoryRecords FROM dbo.StatusHistory;
SELECT Stage, COUNT(*) AS Applications FROM dbo.Applications GROUP BY Stage ORDER BY Stage;
SELECT TOP (20) c.FirstName, c.LastName, v.Title, a.Stage, a.MatchPercent
FROM dbo.Applications a
JOIN dbo.Candidates c ON c.Id = a.CandidateId
JOIN dbo.Vacancies v ON v.Id = a.VacancyId
ORDER BY a.UpdatedAt DESC;
GO
